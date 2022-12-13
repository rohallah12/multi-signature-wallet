//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.6.2 <0.9.0;

contract target is Ownable {

    mapping(address=>uint256) public depositer;
    uint256 public number;

    function getETHBalance() public view returns(uint256){
        return address(this).balance;
    }

    function Deposit() public payable onlyOwner{
        depositer[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public payable onlyOwner{
        depositer[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function setNumber(uint256 newNumber) public onlyOwner{
        number = newNumber;
    }

    receive() external payable{
    }

}