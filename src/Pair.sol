// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Pair is ERC20 {
    using SafeMath for uint256;
    address public factory;

    address public token0;
    address public token1;
    uint112 private _reserve0;
    uint112 private _reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Sync(uint112 _reserve0, uint112 _reserve1);

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

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Pair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(
                MINIMUM_LIQUIDITY
            );
            _mint(address(0), MINIMUM_LIQUIDITY); // Lock liquidity
        } else {
            liquidity = Math.min(
                amount0.mul(_totalSupply) / _reserve0,
                amount1.mul(_totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(to, amount0, amount1);
    }

    function swap(uint amount0Out, uint amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "PAIR: INSUFFICIENT_OUTPUT");
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        require(to != token0 && to != token1, "PAIR: INVALID_TO");

        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "PAIR: INSUFFIENT_LP"
        );

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint amount0In = balance0 > (_reserve0 - amount0Out)
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint amount1In = balance1 > (_reserve1 - amount1Out)
            ? balance1 - (_reserve1 - amount1Out)
            : 0;

        require(amount0In > 0 || amount1In > 0, "PAIR: INSUFFICENT_INPUT");

        uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3)); // 0.3% fee
        uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3)); // 0.3% fee
        require(
            balance0Adjusted.mul(balance1Adjusted) >=
                uint256(_reserve0).mul(_reserve1).mul(1000 ** 2),
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

    function getReserves() external view returns (uint, uint) {
        return (reserve0, reserve1);
    }
}
