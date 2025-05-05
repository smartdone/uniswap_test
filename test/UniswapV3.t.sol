// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "v3-core/contracts/libraries/TransferHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract UniswapV3Test is Test {
    // 以core chain为例
    IUniswapV3Factory factoryV3;
    IUniswapV3Pool testPool;
    IWETH WETH;

    function setUp() public {
        factoryV3 = IUniswapV3Factory(0x526190295AFB6b8736B14E4b42744FBd95203A3a);
        testPool = IUniswapV3Pool(0x59c458bbFa9e4ab5D970523de76D4EC77c44A5D1);
        WETH = IWETH(0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f);
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

    // forge test --fork-url http://127.0.0.1:8579 --match-test testPoolInfo -vvvv
    function testPoolInfo() public view {
        address token0 = testPool.token0();
        address token1 = testPool.token1();
        console.log("token0", token0);
        console.log("token1", token1);
    }

    function calculatePriceLimit(uint160 currentSqrtPriceX96) public pure returns (uint160) {
        // sqrt(0.99) ≈ 0.994987437
        uint160 sqrtPriceLimitX96 = uint160((uint256(currentSqrtPriceX96) * 994987437) / 1e9);
        return sqrtPriceLimitX96;
    }

    // forge test --fork-url http://127.0.0.1:8579 --match-test testPoolSwap -vvvv
    function testPoolSwap() external {
        uint bal = address(this).balance;
        console.log("balance", bal);
        WETH.deposit{value: 1000 ether}();
        uint eth = WETH.balanceOf(address(this));
        console.log("WETH balance", eth);
        (uint160 sqrtPriceX96, , , , , , ) = testPool.slot0();
        console.log("sqrtPriceX96", sqrtPriceX96);
        sqrtPriceX96 = calculatePriceLimit(sqrtPriceX96);
        console.log("sqrtPriceX96 limit", sqrtPriceX96);

        // 价格计算
        // P = (sqrtPriceX96 / 2^96)^2
        // P_limit = P * 0.99
        // sqrtPriceLimitX96 = sqrt(P_limit) * 2^96
        // sqrtPriceX96 = sqrt(P) * 2^96

        // 简化计算
        // sqrtPriceLimitX96 = sqrtPriceX96 * sqrt(0.99)
        // sqrt(0.99) ≈ 0.994987437
        // sqrtPriceLimitX96 = sqrtPriceX96 * 0.994987437
        // sqrtPriceLimitX96 = uint160((uint256(sqrtPriceX96) * 994987437) / 1e9);

        (int256 amount0, int256 amount1) = testPool.swap(
            address(this),
            true, // 方向：token0 -> token1
            int256(1000 ether), // 交换的数量
            sqrtPriceX96, // 价格下限
            abi.encode(testPool.token0(), testPool.token1())
        );
        console.log("amount0", amount0);
        console.log("amount1", amount1);
        eth = WETH.balanceOf(address(this));
        uint token = IERC20(testPool.token1()).balanceOf(address(this));
        console.log("WETH balance", eth);
        console.log("token balance", token);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // TODO 需要验证pool地址, 这里直接简化了，直接这么写会被攻击
        (address token0, address token1) = abi.decode(data, (address, address));
        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(token0, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            TransferHelper.safeTransfer(token1, msg.sender, uint256(amount1Delta));
        }
    }

    // forge test --fork-url http://127.0.0.1:8579 --match-test testPoolFlash -vvvv
    function testPoolFlash() public {
        WETH.deposit{value: 1000 ether}();
        testPool.flash(
            address(this), // 收款地址
            100 ether, // 借款数量
            0, // 借款数量
            abi.encode(testPool.token0(), testPool.token1(), address(testPool), 100 ether, 0) // 额外数据
        );
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        

        // TODO 需要验证pool地址, 这里直接简化了，直接这么写会被攻击
        (address token0, address token1, address pool, uint256 amount0, uint256 amount1) = abi.decode(data, (address, address, address, uint256, uint256));
        uint bal = IERC20(token0).balanceOf(address(this));
        console.log("token0 balance", bal);
        // 归还借款
        if (fee0 > 0) {
            uint256 amount0Owed = amount0 + fee0 ; // Add borrowed amount if needed
            TransferHelper.safeTransfer(token0, pool, amount0Owed);
        }
        if (fee1 > 0) {
            uint256 amount1Owed = amount1 + fee1; // Add borrowed amount if needed
            TransferHelper.safeTransfer(token1, pool, amount1Owed);
        }
        bal = IERC20(token0).balanceOf(address(this));
        console.log("token0 balance", bal);
    }

    receive() external payable {}
    fallback() external payable {}
}