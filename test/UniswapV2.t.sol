// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV2Factory} from "v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract UniswapV2Test is Test {
    // 以core chain为例
    IWETH WETH;
    IUniswapV2Pair testPair;
    IUniswapV2Factory testFactory;

    function setUp() public {
        WETH = IWETH(0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f);
        testPair = IUniswapV2Pair(0xb5aC6a7f20e9ECF8CFEDF614741F78395c3F029d);
        testFactory = IUniswapV2Factory(0x6Edf8aecAA888896385d7fA19D2AA4eaff3C10D8);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // 实现 IUniswapV2Callee 接口，用于处理回调
    function uniswapV2Call(address sender, uint amount0Out, uint amount1Out, bytes calldata data) external {
        (address token0, address token1, address pair, uint amount0In, uint amount1In ) = abi.decode(data, (address, address, address, uint, uint));
        if (amount0In > 0) {
            IERC20(token0).transfer(pair, amount0In);
        }
        if (amount1In > 0) {
            IERC20(token1).transfer(pair, amount1In);
        }
    }

    // pancakeswap的回调函数
    function pancakeCall(address sender, uint amount0Out, uint amount1Out, bytes calldata data) external {
        (address token0, address token1, address pair, uint amount0In, uint amount1In ) = abi.decode(data, (address, address, address, uint, uint));
        if (amount0In > 0) {
            IERC20(token0).transfer(pair, amount0In);
        }
        if (amount1In > 0) {
            IERC20(token1).transfer(pair, amount1In);
        }
    } 

    // forge test --fork-url http://127.0.0.1:8579 --match-test testV2Swap -vvvv
    function testV2Swap() public {
        WETH.deposit{value: 100 ether}();
        address token0 = testPair.token0();
        address token1 = testPair.token1();
        console.log("token0", token0);
        console.log("token1", token1);
        (uint reserveIn, uint reserveOut, ) = testPair.getReserves();
        console.log("reserveIn", reserveIn);
        console.log("reserveOut", reserveOut);
        uint amountIn = 10 ether;
        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        console.log("amountIn", amountIn);
        console.log("amountOut", amountOut);
        uint bal = IERC20(token1).balanceOf(address(this));
        console.log("token1 balance", bal);
        testPair.swap(0, amountOut, address(this), abi.encode(token0, token1, address(testPair), amountIn, 0));
        bal = IERC20(token1).balanceOf(address(this));
        console.log("token1 balance", bal);
    }


}