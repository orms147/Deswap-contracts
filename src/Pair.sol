// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Pair is ERC20 {
    using SafeMath for uint256;

    address public immutable factory;
    address public token0;
    address public token1;

    uint112 private _reserve0;
    uint112 private _reserve1;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    uint private _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1, "Pair: LOCKED");
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    constructor() ERC20("LP Token", "LP") {
        factory = msg.sender;
    }

    function initialize(address token0_, address token1_) external {
        require(msg.sender == factory, "Pair: FORBIDDEN");
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() public view returns (uint112, uint112) {
        return (_reserve0, _reserve1);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "Pair: OVERFLOW"
        );
        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        emit Sync(_reserve0, _reserve1);
    }

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 currentReserve0, uint112 currentReserve1) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(currentReserve0);
        uint256 amount1 = balance1.sub(currentReserve1);

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(
                MINIMUM_LIQUIDITY
            );
            _mint(address(0), MINIMUM_LIQUIDITY); // Lock liquidity
        } else {
            uint256 liquidity0 = amount0.mul(_totalSupply) / currentReserve0;
            uint256 liquidity1 = amount1.mul(_totalSupply) / currentReserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        require(liquidity > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external lock {
        require(amount0Out > 0 || amount1Out > 0, "Pair: INSUFFICIENT_OUTPUT");
        (uint112 currentReserve0, uint112 currentReserve1) = getReserves();
        require(
            amount0Out < currentReserve0 && amount1Out < currentReserve1,
            "Pair: INSUFFICIENT_LIQUIDITY"
        );
        require(to != token0 && to != token1, "Pair: INVALID_TO");

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > currentReserve0 - amount0Out
            ? balance0.sub(currentReserve0 - amount0Out)
            : 0;
        uint256 amount1In = balance1 > currentReserve1 - amount1Out
            ? balance1.sub(currentReserve1 - amount1Out)
            : 0;
        require(amount0In > 0 || amount1In > 0, "Pair: INSUFFICIENT_INPUT");

        uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(
            balance0Adjusted.mul(balance1Adjusted) >=
                uint256(currentReserve0).mul(currentReserve1).mul(1000 ** 2),
            "Pair: K_INVARIANT"
        );

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Pair: TRANSFER_FAILED"
        );
    }
}
