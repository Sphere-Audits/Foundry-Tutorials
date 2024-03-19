// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "forge-std/console.sol";
import {CPAMM} from "../src/AMM.sol";

contract CPAMMTest is Test {
    MockERC20 token0;
    MockERC20 token1;
    CPAMM amm;

    function setUp() public {
        token0 = new MockERC20("Ram", "RAM", 18);
        token1 = new MockERC20("Shyam", "SHYAM", 18);

        amm = new CPAMM(address(token0), address(token1));

        token0.mint(address(this), 1000);
        token1.mint(address(this), 500);
        // console.log("Token0 balance: ", token0.balanceOf(address(this)));
        // console.log("Token1 balance: ", token1.balanceOf(address(this)));

        token0.approve(address(amm), 1000);
        token1.approve(address(amm), 500);
        // console.log("Token0 allowance: ", token0.allowance(address(this), address(amm)));
        // console.log("Token1 allowance: ", token1.allowance(address(this), address(amm)));
        
    }

    function test_addLiquidity() public {
        uint256 amount0 = 1000;
        uint256 amount1 = 500;
        
        /* 
        ADD LIQUIDITY

        shares = sqrt(amount0 * amount1)

        sqrt(1000 * 500) 

        sqrt(500000)

        ~707

        */
        uint256 shares = amm.addLiquidity(amount0, amount1);
        
        // console.log("Shares: ", shares);
        // console.log("Total Supply: ", amm.totalSupply());
        assertEq(amm.balanceOf(address(this)), shares);
        assertEq(amm.totalSupply(), shares);
    }

    function test_removeLiquidity() public {
        uint256 amount0 = 1000;
        uint256 amount1 = 500;

        uint256 shares = amm.addLiquidity(amount0, amount1);
        // console.log("Shares: ", shares);

        // remove liquidity
        (uint256 _amount0, uint256 _amount1) = amm.removeLiquidity(shares);
        // console.log("Amount0: ", _amount0);
        // console.log("Amount1: ", _amount1);

        assertEq(_amount0, amount0);
        assertEq(_amount1, amount1);
    }

    function test_swap() public {
        uint256 amount0 = 1000;
        uint256 amount1 = 500;

        uint256 shares = amm.addLiquidity(amount0, amount1);
        // console.log("Shares: ", shares);

        // approve
        token0.mint(address(this), 45);
        token0.approve(address(amm), 45);

        // console.log("Token0 Balance of CPAMMTest:", token0.balanceOf(address(this)));
        // console.log("Token0 Allowance for CPAMM:", token0.allowance(address(this), address(amm)));

        /*
        reserve0 (token0 liquidity) = 1000
        reserve1 (token1 liquidity) = 500
        amountIn (amount of token0 being swapped) = 45
        Fee = 0.3% or 0.003 in decimal form

        amountInWithFee = (45 * 997) / 1000 = 44865 / 1000 = 44.865

        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee)

        amountOut = (500 * 44) / (1000 + 44) = 22000 / 1044 ≈ 21
         */
        uint256 amountOut = amm.swap(address(token0), 45);

        // console.log("Amountout", token1.balanceOf(address(this)));
        // console.log("Reserve value of token0", amm.reserve0());
        // console.log("Reserve value of token1", amm.reserve1());

        assertEq(amountOut, 21);
        assertEq(amm.reserve0(), 1000 + 45);
        assertEq(amm.reserve1(), 500 - 21);
        assertEq(shares, amm.totalSupply());
    }
}

contract CPAMMFuzzTest is Test {
    MockERC20 token0;
    MockERC20 token1;
    CPAMM amm;

    function setUp() public {
        token0 = new MockERC20("Ram", "RAM", 18);
        token1 = new MockERC20("Shyam", "SHYAM", 18);

        amm = new CPAMM(address(token0), address(token1));

        // token0.mint(address(this), 1e24);
        // token1.mint(address(this), 1e24);

        // token0.approve(address(amm), type(uint256).max);
        // token1.approve(address(amm), type(uint256).max);
    }

    function testFuzz_addLiquidity(uint256 amount0, uint256 amount1) public {
        vm.assume(amount0 > 0 && amount0 < 1e24);
        vm.assume(amount1 > 0 && amount1 < 1e24);

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        token0.approve(address(amm), amount0);
        token1.approve(address(amm), amount1);

        uint256 shares = amm.addLiquidity(amount0, amount1);

        assertTrue(shares > 0, "Shares should be greater than 0");
        assertEq(amm.totalSupply(), shares);
        assertEq(amm.reserve0(), amount0);
    }

    function testFuzz_removeLiquidity(uint256 amount0, uint256 amount1) public {
        vm.assume(amount0 > 0 && amount0 < 1e24);
        vm.assume(amount1 > 0 && amount1 < 1e24);

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        token0.approve(address(amm), amount0);
        token1.approve(address(amm), amount1);

        uint256 shares = amm.addLiquidity(amount0, amount1);

        (uint256 _amount0, uint256 _amount1) = amm.removeLiquidity(shares);

        assertEq(_amount0, amount0);
        assertEq(_amount1, amount1);
        assertEq(amm.totalSupply(), 0);
    }

    function testFuzz_Swap(uint256 amount0, uint256 amount1, uint256 amountIn) public {
        vm.assume(amount0 > 0 && amount0 < 1e24);
        vm.assume(amount1 > 0 && amount1 < 1e24);
        vm.assume(amountIn > 0 && amountIn < 1e24);

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        token0.approve(address(amm), amount0);
        token1.approve(address(amm), amount1);

        uint256 shares = amm.addLiquidity(amount0, amount1);

        token0.mint(address(this), amountIn);
        token0.approve(address(amm), amountIn);

        uint256 amountOut = amm.swap(address(token0), amountIn);
        console.log("AmountOut: ", amountOut);

        assertEq(amm.reserve0(), amount0 + amountIn);   
        assertEq(amm.reserve1(), amount1 - amountOut);
    }
}