updateExchangeRate() 函数从 oracle 中获取最新的Rate，如果获取成功，更新 exchangeRate，否则返回旧的Rate。
```solidity
function updateExchangeRate() public returns (bool updated, uint256 rate) {
    (updated, rate) = oracle.get(oracleData);

    if (updated) {
        exchangeRate = rate;
        emit LogExchangeRate(rate);
    } else {
        // Return the old rate if fetching wasn't successful
        rate = exchangeRate;
    }
}
```
而**exchangeRate**在评估用户是否有足够的资金来偿还借款(isSolvent check)时，会被调用。
```solidity
function _isSolvent(
    address user,
    bool open,
    uint256 _exchangeRate
) internal view returns (bool) {
    // accrue must have already been called!
    uint256 borrowPart = userBorrowPart[user];
    if (borrowPart == 0) return true;
    uint256 collateralShare = userCollateralShare[user];
    if (collateralShare == 0) return false;

    Rebase memory _totalBorrow = totalBorrow;

    return
        bentoBox.toAmount(
            collateral,
            collateralShare.mul(EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION).mul(
                open ? OPEN_COLLATERIZATION_RATE : CLOSED_COLLATERIZATION_RATE
            ),
            false
        ) >=
        // Moved exchangeRate here instead of dividing the other side to preserve more precision
        borrowPart.mul(_totalBorrow.elastic).mul(_exchangeRate) / _totalBorrow.base;
}

/// @dev Checks if the user is solvent in the closed liquidation case at the end of the function body.
modifier solvent() {
    _;
    require(_isSolvent(msg.sender, false, exchangeRate), "KashiPair: user insolvent");
}
```

而在brrow()函数中，**没有调用updateExchangeRate()去更新exchangeRate**

```solidity
function borrow(address to, uint256 amount) public solvent returns (uint256 part, uint256 share) {
    accrue();
    (part, share) = _borrow(to, amount);
}
```

但是在liquidate()清算函数中，调用了updateExchangeRate()去更新exchangeRate

```solidity
function liquidate(
    address[] calldata users,
    uint256[] calldata maxBorrowParts,
    address to,
    ISwapper swapper,
    bool open
) public {
    // Oracle can fail but we still need to allow liquidations
    (, uint256 _exchangeRate) = updateExchangeRate();
    accrue();

    uint256 allCollateralShare;
    uint256 allBorrowAmount;
    uint256 allBorrowPart;
    Rebase memory _totalBorrow = totalBorrow;
    Rebase memory bentoBoxTotals = bentoBox.totals(collateral);
    for (uint256 i = 0; i < users.length; i++) {
        address user = users[i];
        if (!_isSolvent(user, open, _exchangeRate)) {
            uint256 borrowPart;
            {
                uint256 availableBorrowPart = userBorrowPart[user];
                borrowPart = maxBorrowParts[i] > availableBorrowPart ? availableBorrowPart : maxBorrowParts[i];
                userBorrowPart[user] = availableBorrowPart.sub(borrowPart);
            }
            uint256 borrowAmount = _totalBorrow.toElastic(borrowPart, false);
            uint256 collateralShare =
                bentoBoxTotals.toBase(
                    borrowAmount.mul(LIQUIDATION_MULTIPLIER).mul(_exchangeRate) /
                        (LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION),
                    false
                );

            userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
            emit LogRemoveCollateral(user, swapper == ISwapper(0) ? to : address(swapper), collateralShare);
            emit LogRepay(swapper == ISwapper(0) ? msg.sender : address(swapper), user, borrowAmount, borrowPart);

            // Keep totals
            allCollateralShare = allCollateralShare.add(collateralShare);
            allBorrowAmount = allBorrowAmount.add(borrowAmount);
            allBorrowPart = allBorrowPart.add(borrowPart);
        }
    }
    require(allBorrowAmount != 0, "KashiPair: all are solvent");
    _totalBorrow.elastic = _totalBorrow.elastic.sub(allBorrowAmount.to128());
    _totalBorrow.base = _totalBorrow.base.sub(allBorrowPart.to128());
    totalBorrow = _totalBorrow;
    totalCollateralShare = totalCollateralShare.sub(allCollateralShare);

    uint256 allBorrowShare = bentoBox.toShare(asset, allBorrowAmount, true);

    if (!open) {
        // Closed liquidation using a pre-approved swapper for the benefit of the LPs
        require(masterContract.swappers(swapper), "KashiPair: Invalid swapper");

        // Swaps the users' collateral for the borrowed asset
        bentoBox.transfer(collateral, address(this), address(swapper), allCollateralShare);
        swapper.swap(collateral, asset, address(this), allBorrowShare, allCollateralShare);

        uint256 returnedShare = bentoBox.balanceOf(asset, address(this)).sub(uint256(totalAsset.elastic));
        uint256 extraShare = returnedShare.sub(allBorrowShare);
        uint256 feeShare = extraShare.mul(PROTOCOL_FEE) / PROTOCOL_FEE_DIVISOR; // % of profit goes to fee
        // solhint-disable-next-line reentrancy
        bentoBox.transfer(asset, address(this), masterContract.feeTo(), feeShare);
        totalAsset.elastic = totalAsset.elastic.add(returnedShare.sub(feeShare).to128());
        emit LogAddAsset(address(swapper), address(this), extraShare.sub(feeShare), 0);
    } else {
        // Swap using a swapper freely chosen by the caller
        // Open (flash) liquidation: get proceeds first and provide the borrow after
        bentoBox.transfer(collateral, address(this), swapper == ISwapper(0) ? to : address(swapper), allCollateralShare);
        if (swapper != ISwapper(0)) {
            swapper.swap(collateral, asset, msg.sender, allBorrowShare, allCollateralShare);
        }

        bentoBox.transfer(asset, msg.sender, address(this), allBorrowShare);
        totalAsset.elastic = totalAsset.elastic.add(allBorrowShare.to128());
    }
}
```

可以导致在一笔交易中，borrow时的exchangeRate和liquidate时的exchangeRate不一致，攻击者可以通过闪电贷从中获利。