// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract UniswapV3Test is Test {
    // 以core chain为例
    IUniswapV3Factory factoryV3;
    function setUp() public {
        factoryV3 = IUniswapV3Factory(0x526190295AFB6b8736B14E4b42744FBd95203A3a);
    }

    // forge test --fork-url http://127.0.0.1:8579 --match-test testFactoryAllFees -vvvv
    function testFactoryAllFees() public view {
        // feeAmountTickSpacing 可以在factory的constructor中看到默认的值
        // 然后可以在enableFeeAmount函数调用中看到新添加的
        // core chain上有:
        // 100 1
        // 500 10
        // 3000 60
        // 10000 200

        // 如果合约没开源，你可以从0遍历到1000000，tickSpacing不为0的就是
        for(uint24 i = 0; i < 500; i++) {
            int64 tickSpacing = factoryV3.feeAmountTickSpacing(i);
            if (tickSpacing > 0) {
                console.log("fee", i);
                console.log("tickSpacing", tickSpacing);
            }
        }
    }
}