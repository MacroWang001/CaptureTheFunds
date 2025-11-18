// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Wrapped Ether (WETH)
/// @notice A simple ERC20 implementation that wraps ETH.
contract WETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // Automatically deposit when ETH is sent directly
    receive() external payable {
        deposit();
    }
    
    /// @notice Deposits ETH and mints WETH tokens.
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    /// @notice Burns WETH tokens and sends back ETH.
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "WETH: insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
        emit Transfer(msg.sender, address(0), wad);
    }
    
    /// @notice Returns the total supply (equal to the ETH held by the contract).
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice Transfers WETH tokens.
    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "WETH: insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    /// @notice Approves an address to spend WETH tokens.
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    /// @notice Transfers WETH tokens from one address to another.
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "WETH: insufficient balance");
        require(allowance[from][msg.sender] >= value, "WETH: allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}
