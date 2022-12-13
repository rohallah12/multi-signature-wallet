// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";
import "../src/multisig.sol";
import "forge-std/Test.sol";
import "../src/target.sol";

pragma solidity >=0.6.2 <0.9.0;

contract signer is Ownable{
    multiSigWallet wallet;

    function setMultiSigWallet(multiSigWallet msw) public {
       wallet = msw; 
    } 

    function approve(uint256 _txId) public onlyOwner {
        wallet.approveTx(_txId);
    }

    function revoke(uint256 _txId) public onlyOwner {
        wallet.revokeTx(_txId);
    }

    function create(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        wallet.createTx(_to, _data, _value);
    }

    function execute(uint256 _txId) public onlyOwner {
        wallet.executeTx(_txId);
    }

    receive() external payable{}
}

contract multiSigTest is Test {

    target t;
    multiSigWallet ms;
    uint256 signersCount = 5;
    uint256 minRequired = 3; 
    uint256 targetNumber = 10;
    uint256 approvers = 2;
    address[] signers;

    function setUp() public {
        signer ns;
        for(uint256 i = 0; i < signersCount; i++){
            ns = new signer();
            signers.push(address(ns));
        }

        ms = new multiSigWallet(signers, minRequired); 

        for(uint256 i = 0; i < signersCount; i++){
            signer(payable(signers[i])).setMultiSigWallet(ms);
        }

        t = new target();
        t.transferOwnership(address(ms));
    }


    function testChangeNumber() public {
        bytes memory data = abi.encodeWithSignature("setNumber(uint256)", targetNumber);
        uint256 txId = 0;

        signer(payable(signers[0])).create(address(t), 0, data);

        assertEq(ms.getApprovalsCount(txId), 1);

        for(uint256 i = 1; i < approvers + 1; i++){
            signer(payable(signers[i])).approve(txId);
        }

        assertEq(ms.getApprovalsCount(txId), 1 + approvers);

        signer(payable(signers[0])).execute(txId);

        uint256 tnumber = t.number();
        assertEq(tnumber, targetNumber);
    }

    function testSendValue() public {
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("Deposit()", value);
        uint256 txId = 0;

        signer(payable(signers[0])).create(address(t), value, data);

        assertEq(ms.getApprovalsCount(txId), 1);

        for(uint256 i = 1; i < approvers + 1; i++){
            signer(payable(signers[i])).approve(txId);
        }

        assertEq(ms.getApprovalsCount(txId), 1 + approvers);

        vm.deal(address(ms), 100 ether);
        
        signer(payable(signers[0])).execute(txId);
        assertEq(t.getETHBalance(), value);
    }

    function testRevoke() public {
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("Deposit()", value);
        uint256 txId = 0;

        signer(payable(signers[0])).create(address(t), value, data);

        assertEq(ms.getApprovalsCount(txId), 1);

        for(uint256 i = 1; i < approvers + 1; i++){
            signer(payable(signers[i])).approve(txId);
        }

        assertEq(ms.getApprovalsCount(txId), 1 + approvers);

        vm.deal(address(ms), 100 ether);

        signer(payable(signers[0])).execute(txId);
        assertEq(t.getETHBalance(), value);

        txId += 1;

        signer(payable(signers[0])).create(address(t), value, data);

        assertEq(ms.getApprovalsCount(txId), 1);

        for(uint256 i = 1; i < approvers + 1; i++){
            signer(payable(signers[i])).approve(txId);
        }

        assertEq(ms.getApprovalsCount(txId), 1 + approvers);

        vm.deal(address(ms), 100 ether);

        signer(payable(signers[0])).execute(txId);
        assertEq(t.getETHBalance(), value * 2);

    }

    function testFundETH() public payable{
        vm.deal(address(this), 100 ether);
        ms.DepositETH{value : 10 ether}();
        uint256 bb = address(this).balance;
        ms.withdrawETH(10 ether);
        assertEq(address(this).balance - bb, 10 ether);
    }

    receive() external payable{}
}
