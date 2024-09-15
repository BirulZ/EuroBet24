// contracts/EuroBetToken.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Capped.sol";

//test
contract EuroBetToken is ERC20Capped, ERC20Burnable {  //Burnable dadurch, dass wir nicht wissen ob das Cap zuviel ist, können wir sie danach burnen
    address payable public owner;
    uint256 public blockReward;
    mapping(address => bool) public bettingContracts; //alle die wetten dürfen

    constructor(uint256 cap, uint256 reward) ERC20("EuroBetToken", "EBT") ERC20Capped (cap * (10 ** decimals())){ //10 Millionen CAP Tokens
        owner = payable(msg.sender);
        _mint(owner, 5000000 * (10 ** decimals())); // Erstell den Token und schick den ganzen Supply an mich, 
        blockReward = reward * (10 ** decimals());  // Block-Reward setzen, 
    }

    // Token
    function _mintMinerReward() internal {
        _mint(block.coinbase, blockReward);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20Capped, ERC20) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
        if(from != address(0) && to != block.coinbase && block.coinbase != address(0) && ERC20.totalSupply() + blockReward <= cap()) {
            _mintMinerReward();
        }
        super._beforeTokenTransfer(from, to, value);
    }

    // Blockreward setzen
    function setBlockReward(uint256 reward) public onlyOwner {
        blockReward = reward * (10 ** decimals());
    }

    // Wenn man Rewards ändern möchte, aber nur wir es dürfen bzw. können
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Damit man nicht als owner jede einzelne Addresse die wetten möchte, vorher erst approven muss
    function setBettingContract(address _bettingContract, bool status) public onlyOwner {
        bettingContracts[_bettingContract] = status;
    }

    function transferForBetting(address from, address to, uint256 amount) public returns (bool) {
        require(bettingContracts[msg.sender] == true, "Only betting contracts can call this");
        _transfer(from, to, amount);
        return true;
    }
}
