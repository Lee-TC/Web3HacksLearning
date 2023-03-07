## Platypusdefi

look at this code, emergencyWithdraw function use isSolvent check **BEFORE** transfer token to user.

emergencyWithdraw() 实现了紧急提现功能。但是，合约检测用户是否有能力偿还(isSolvent check)**早于**转账资产，这样就导致了用户在紧急提现时，即使他的资产不足以抵押，也可以正常提现。

``` solidity
function emergencyWithdraw(uint256 _pid) public nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (address(platypusTreasure) != address(0x00)) {
        (bool isSolvent, ) = platypusTreasure.isSolvent(msg.sender, address(poolInfo[_pid].lpToken), true);
        require(isSolvent, 'remaining amount exceeds collateral factor');
    }

    // reset rewarder before we update lpSupply and sumOfFactors
    IBoostedMultiRewarder rewarder = pool.rewarder;
    if (address(rewarder) != address(0)) {
        rewarder.onPtpReward(msg.sender, user.amount, 0, user.factor, 0);
    }

    // SafeERC20 is not needed as Asset will revert if transfer fails
    pool.lpToken.transfer(address(msg.sender), user.amount);

    // update non-dialuting factor
    pool.sumOfFactors -= user.factor;

    user.amount = 0;
    user.factor = 0;
    user.rewardDebt = 0;

    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
}
```

有趣的是，同一个合约，withdraw() 函数却是在转账之后再检测用户是否有能力偿还。

``` solidity
function withdraw(uint256 _pid, uint256 _amount)
    external
    override
    nonReentrant
    whenNotPaused
    returns (uint256 reward, uint256[] memory additionalRewards)
{
    (reward, additionalRewards) = _withdrawFor(_pid, msg.sender, msg.sender, _amount);

    if (address(platypusTreasure) != address(0x00)) {
        (bool isSolvent, ) = platypusTreasure.isSolvent(msg.sender, address(poolInfo[_pid].lpToken), true);
        require(isSolvent, 'remaining amount exceeds collateral factor');
    }
}
```