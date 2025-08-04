// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ERC20Mock is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor(string memory _name, string memory _symbol, uint _supply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _supply;
        balanceOf[msg.sender] = _supply;
    }

    function transfer(
        address recipient,
        uint amount
    ) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(
        address spender,
        uint amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external override returns (bool) {
        require(
            allowance[sender][msg.sender] >= amount,
            "ERC20: insufficient allowance"
        );
        require(balanceOf[sender] >= amount, "ERC20: insufficient balance");
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
}

contract SimpleDEXTest is Test {
    Factory public factory;
    Router public router;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public tokenC;

    address public user = address(0x123);

    function setUp() public {
        vm.prank(address(this));
        tokenA = new ERC20Mock("TokenA", "TKA", 1_000_000 ether);
        vm.prank(address(this));
        tokenB = new ERC20Mock("TokenB", "TKB", 1_000_000 ether);
        vm.prank(address(this));
        tokenC = new ERC20Mock("TokenC", "TKC", 1_000_000 ether);

        factory = new Factory();
        router = new Router(address(factory));

        vm.startPrank(user);
        factory.createPair(address(tokenA), address(tokenB));
        factory.createPair(address(tokenB), address(tokenC));
        vm.stopPrank();

        tokenA.transfer(user, 500_000 ether);
        tokenB.transfer(user, 500_000 ether);
        tokenC.transfer(user, 500_000 ether);
    }

    function testAddLiquidity() public {
        vm.startPrank(user);
        tokenA.approve(address(router), 10_000 ether);
        tokenB.approve(address(router), 10_000 ether);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10_000 ether,
            10_000 ether
        );

        address pairAddr = factory.getPair(address(tokenA), address(tokenB));
        Pair pairContract = Pair(pairAddr);

        assertEq(tokenA.balanceOf(pairAddr), 10_000 ether);
        assertEq(tokenB.balanceOf(pairAddr), 10_000 ether);
        assertEq(pairContract.balanceOf(user), 10_000 ether);
        vm.stopPrank();
    }

    function testSwapSingleHop() public {
        vm.startPrank(user);
        tokenA.approve(address(router), 10_000 ether);
        tokenB.approve(address(router), 10_000 ether);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10_000 ether,
            20_000 ether
        );
        vm.stopPrank();

        vm.startPrank(user);
        uint256 userBalanceB_before = tokenB.balanceOf(user);
        tokenA.approve(address(router), 100 ether);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint[] memory amountsOut = router.getAmountsOut(10 ether, path);
        uint256 expectedAmountOut = amountsOut[1];

        router.swapExactTokensForTokens(
            10 ether,
            (expectedAmountOut * 99) / 100,
            path,
            user
        );
        assertEq(
            tokenB.balanceOf(user),
            userBalanceB_before + expectedAmountOut
        );
        vm.stopPrank();
    }

    function testSwapMultiHop() public {
        vm.startPrank(user);
        tokenA.approve(address(router), 10_000 ether);
        tokenB.approve(address(router), 10_000 ether);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10_000 ether,
            10_000 ether
        );

        tokenB.approve(address(router), 10_000 ether);
        tokenC.approve(address(router), 10_000 ether);
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            10_000 ether,
            10_000 ether
        );
        vm.stopPrank();

        vm.startPrank(user);
        uint256 userBalanceC_before = tokenC.balanceOf(user);
        tokenA.approve(address(router), 100 ether);

        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        uint[] memory amountsOut = router.getAmountsOut(10 ether, path);
        uint256 expectedAmountOut = amountsOut[2];

        router.swapExactTokensForTokens(
            10 ether,
            (expectedAmountOut * 99) / 100,
            path,
            user
        );
        assertEq(
            tokenC.balanceOf(user),
            userBalanceC_before + expectedAmountOut
        );
        vm.stopPrank();
    }
}
