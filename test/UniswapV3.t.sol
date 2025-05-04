// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract UniswapV3Test is Test {
    // 以core chain为例
    IUniswapV3Factory factoryV3;
    IUniswapV3Pool testPool;

    function setUp() public {
        factoryV3 = IUniswapV3Factory(0x526190295AFB6b8736B14E4b42744FBd95203A3a);
        testPool = IUniswapV3Pool(0x59c458bbFa9e4ab5D970523de76D4EC77c44A5D1);
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

        // 手续费计算方式为 fee/1000000 比如500就是0.0005也就是0.05%

        // 如果合约没开源，你可以从0遍历到1000000，tickSpacing不为0的就是
        for(uint24 i = 0; i < 500; i++) {
            int64 tickSpacing = factoryV3.feeAmountTickSpacing(i);
            if (tickSpacing > 0) {
                console.log("fee", i);
                console.log("tickSpacing", tickSpacing);
            }
        }
    }

    // forge test --fork-url http://127.0.0.1:8579 --match-test testPoolSlot -vvvv
    function testPoolSlot() public view {
        (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) = testPool.slot0();
        // 当前价格
        console.log("sqrtPriceX96", sqrtPriceX96);
        // 当前价格的tick
        console.log("tick", tick);
        // observations数组中最近一次更新的索引
        console.log("observationIndex", observationIndex);
        //当前正在存储的最大观测值数量
        console.log("observationCardinality", observationCardinality);
        // 在 observations.write 被触发时，下一个要存储的最大观测值数量
        console.log("observationCardinalityNext", observationCardinalityNext);
        // 当前协议手续费（protocol fee）以整数分母（1/x）的形式表示为在提款时从交换手续费（swap fee）中提取的百分比。
        console.log("feeProtocol", feeProtocol);
        // 池子是否被锁定
        console.log("unlocked", unlocked);
    }
}