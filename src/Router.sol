// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Factory.sol";
import "./Pair.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Router {
    using SafeMath for uint256;
    Factory public immutable factory;

    constructor(address _factory) {
        factory = Factory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB
    ) external {
        address pair = factory.getPair(tokenA, tokenB);

        if (pair == address(0)) {
            pair = factory.createPair(tokenA, tokenB);
        }

        require(
            IERC20(tokenA).transferFrom(msg.sender, pair, amountA),
            "Transfer of tokenA failed"
        );
        require(
            IERC20(tokenB).transferFrom(msg.sender, pair, amountB),
            "Transfer of tokenB failed"
        );

        Pair(pair).mint(msg.sender);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to
    ) external {
        address pair = factory.getPair(tokenIn, tokenOut);

        require(pair != address(0), "Router: PAIR_DOES_NOT_EXIST");

        // get reserves from pair
        (uint reserve0, uint reserve1) = Pair(pair).getReserves();

        address token0 = Pair(pair).token0();
        //address token1 = Pair(pair).token1();

        (uint reserveIn, uint reserveOut) = tokenIn == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        // calc with amm
        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        require(amountOut >= amountOutMin, "ROUTER: INSUFFICIENT_OUTPUT");

        IERC20(tokenIn).transferFrom(msg.sender, pair, amountIn);

        (uint amount0Out, uint amount1Out) = tokenIn == token0
            ? (uint(0), amountOut)
            : (amountOut, uint(0));

        Pair(pair).swap(amount0Out, amount1Out, to);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to
    ) external {
        require(path.length >= 2, "ROUTER: INVALID_PATH");

        // Tính tổng amount out để kiểm tra slippage
        uint[] memory amounts = getAmountsOut(amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "ROUTER: INSUFFICIENT_OUTPUT"
        );

        // Transfer token đầu tiên
        IERC20(path[0]).transferFrom(
            msg.sender,
            getPair(path[0], path[1]),
            amountIn
        );

        // Swap step by step
        for (uint i = 0; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pair = getPair(input, output);

            require(pair != address(0), "ROUTER: PAIR_DOES_NOT_EXIST");

            (uint reserveIn, uint reserveOut) = getReserves(input, output);
            uint amountInput = IERC20(input).balanceOf(pair) - reserveIn;
            uint amountOut = getAmountOut(amountInput, reserveIn, reserveOut);

            // Xác định địa chỉ nhận cho swap tiếp theo
            address recipient = i < path.length - 2
                ? getPair(output, path[i + 2])
                : to;

            // Xác định token0 để set amount0Out và amount1Out đúng
            address token0 = Pair(pair).token0();
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));

            Pair(pair).swap(amount0Out, amount1Out, recipient);
        }
    }

    // Helper function để tính amounts out cho toàn bộ path
    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view returns (uint[] memory amounts) {
        require(path.length >= 2, "ROUTER: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i = 0; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "Router: INSUFFICIENT_INPUT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "Router: "
            "INSUFFICIENT_LP"
        );

        //fee = 0.3%
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function getPair(
        address tokenA,
        address tokenB
    ) internal view returns (address) {
        return factory.getPair(tokenA, tokenB);
    }

    function getReserves(
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        address pair = getPair(tokenA, tokenB);

        (uint reserve0, uint reserve1) = Pair(pair).getReserves();

        (reserveA, reserveB) = tokenA < tokenB
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }
}
