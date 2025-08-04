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

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "Router: EXPIRED");
        _;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        address pairAddress = factory.getPair(tokenA, tokenB);
        if (pairAddress == address(0)) {
            pairAddress = factory.createPair(tokenA, tokenB);
        }
        IERC20(tokenA).transferFrom(msg.sender, pairAddress, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pairAddress, amountB);
        Pair(pairAddress).mint(to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT"
        );
        IERC20(path[0]).transferFrom(
            msg.sender,
            factory.getPair(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            address pairAddress = factory.getPair(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = Pair(pairAddress)
                .token0() == input
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));

            address recipient = i < path.length - 2
                ? factory.getPair(output, path[i + 2])
                : _to;
            Pair(pairAddress).swap(amount0Out, amount1Out, recipient);
        }
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "Router: INVALID_AMOUNTS"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        return numerator / denominator;
    }

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pairAddress) {
        pairAddress = factory.getPair(tokenA, tokenB);
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "Router: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getReserves(
        address tokenA,
        address tokenB
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        address pairAddress = factory.getPair(tokenA, tokenB);
        (uint112 _reserve0, uint112 _reserve1) = Pair(pairAddress)
            .getReserves();
        (reserveA, reserveB) = Pair(pairAddress).token0() == tokenA
            ? (_reserve0, _reserve1)
            : (_reserve1, _reserve0);
    }
}
