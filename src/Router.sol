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

            // Nếu là bước cuối, gửi cho người nhận, nếu không, gửi cho cặp tiếp theo
            address recipient = i < path.length - 2
                ? factory.getPair(output, path[i + 2])
                : _to;
            Pair(pairAddress).swap(amount0Out, amount1Out, recipient);
        }
    }

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
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "Router: INVALID_AMOUNTS"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function _getPair(
        address tokenA,
        address tokenB
    ) internal view returns (address) {
        return factory.getPair(tokenA, tokenB);
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
