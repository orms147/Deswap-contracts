// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FactoryToken {
    event TokenCreated(
        address tokenAddr,
        string name,
        string symbol,
        uint256 totalSupply
    );
    function createToken(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) external {
        MyToken newToken = new MyToken(
            name_,
            symbol_,
            totalSupply_,
            msg.sender
        );
        emit TokenCreated(address(newToken), name_, symbol_, totalSupply_);
    }
}

contract MyToken is ERC20 {
    address private s_owner;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address sender
    ) ERC20(name_, symbol_) {
        s_owner = sender;
        if (totalSupply_ > 0) {
            //msg.sender
            _mint(sender, totalSupply_);
        }
    }

    modifier onlyowner() {
        require(s_owner == msg.sender, "Not the owner");
        _;
    }

    function mint(address _to, uint256 _value) public onlyowner {
        _mint(_to, _value);
    }
}
