//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity >=0.6.2 <0.9.0;

contract multiSigWallet is ReentrancyGuard{
    using SafeERC20 for IERC20;

    enum TxStatus {
       PENDING,
       EXECUTED 
    }

    struct Transaction {
        uint256 _id;
        address _to;
        uint256 _value;
        bytes _calldata;
        uint256 _approved;
        TxStatus _status;
    }

    mapping(uint256=>mapping(address=>bool)) signed;
    mapping(address=>bool) public isValidSigner;
    mapping(address=>uint256) public ethBalances;
    mapping(address=>mapping(address=>uint256)) tokenBalances;

    address[] public owners;
    Transaction[] public txs;
    
    uint256 public minRequired;

    modifier onlyOwners() {
        require(isValidSigner[msg.sender], "not a valid signer");
       _; 
    }

    modifier notExecuted(uint256 _txId) {
       require(txs[_txId]._status == TxStatus.PENDING, "Transaction is already executed!"); 
       _;
    }

    modifier exists(uint256 _txId) {
       require(_txId < txs.length, "Transaction does not exist"); 
       _;
    }

    modifier notSigned(uint256 _txId) {
       require(signed[_txId][msg.sender] == false, "already signed!"); 
       _;
    }

    modifier isSigned(uint256 _txId) {
       require(signed[_txId][msg.sender] == true, "you did not sign!"); 
       _;
    }

    modifier reachedMin(uint256 _txId) {
       require(txs[_txId]._approved >= minRequired, "minimum signers did not reach"); 
       _;
    }

    event depositedETH(address indexed sender, uint256 indexed amount);
    event depositedTokens(address indexed sender, address indexed token, uint256 indexed amount);
    event withdrawedETH(address indexed receiver, uint256 indexed amount);
    event withdrawedTokens(address indexed receiver,address indexed token, uint256 indexed amount);
    event approved(address indexed approved, uint256 indexed txId);
    event revoked(address indexed revoker, uint256 indexed txId);
    event executed(address indexed executor, uint256 indexed txId);
    event created(address indexed creator, uint256 indexed txid);


    constructor(address[] memory _signers, uint256 _minRequired)
    {
        require(_signers.length > 2, "must provide at least 2 owners.");
        require(_minRequired >= _signers.length / 2, "at least 50% of ownres must agree on a tranasction");
        require(_minRequired <= _signers.length, "min signers should be less than signers length");

        for(uint256 i = 0; i < _signers.length; i++){
            require(isValidSigner[_signers[i]] == false, "duplicate signer");
            isValidSigner[_signers[i]] = true;
            owners.push(_signers[i]);
        }
        minRequired = _minRequired;
    }

    function getApprovalsCount(uint256 _txId) public view returns(uint256){
        return txs[_txId]._approved;
    }

    //Deposit ETH to wallet
    function DepositETH() public payable{
        ethBalances[msg.sender] += msg.value;
        emit depositedETH(msg.sender, msg.value);
    }


    //Deposit Tokens to wallet
    function DepositTokens(address _token, uint256 _amount) public {
        IERC20(_token).safeTransferFrom(msg.sender ,address(this), _amount);
        tokenBalances[_token][msg.sender] += _amount;
        emit depositedTokens(msg.sender, _token, _amount);
    }


    //Withdraw ETH
    function withdrawETH(uint256 ethAmount) public payable nonReentrant{
        require(ethAmount <= ethBalances[msg.sender], "not enough eth balance"); 
        ethBalances[msg.sender] -= ethAmount;
        (bool success, ) = payable(msg.sender).call{value : ethAmount}(""); 
        require(success, "transferring eth failed");
        emit withdrawedETH(msg.sender, ethAmount);
    }


    //Withdrawing tokens
    function withdrawTokens(address _token, uint256 _amount) public nonReentrant{
        require(_amount <= tokenBalances[_token][msg.sender],"not enough token balance");
        tokenBalances[_token][msg.sender] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit withdrawedTokens(msg.sender, _token, _amount);
    }

    //Creating a new transaction
    function createTx(address _to, bytes memory _calldata, uint256 _value) public onlyOwners{
        uint256 txId = txs.length;  
        Transaction memory Tx = Transaction(txId, _to, _value, _calldata, 0, TxStatus.PENDING);

        Tx._approved += 1; //one that created the tx approved the transaction by default
        signed[txId][msg.sender] = true;

        txs.push(Tx);
        emit created(msg.sender, txId);
    }

    //Approving a transaction
    function approveTx(uint256 _txId) public onlyOwners notExecuted(_txId) exists(_txId) notSigned(_txId) nonReentrant {
        signed[_txId][msg.sender] = true;
        txs[_txId]._approved += 1; 
        emit approved(msg.sender, _txId);
    }

    //Executing transaction
    function executeTx(uint256 _txId) public payable onlyOwners notExecuted(_txId) exists(_txId) reachedMin(_txId) nonReentrant{
        address target = txs[_txId]._to;
        txs[_txId]._status = TxStatus.EXECUTED;
        (bool success, ) = payable(target).call{value : txs[_txId]._value}(txs[_txId]._calldata); 
        require(success, "Transaction failed");
        emit executed(msg.sender, _txId);
    }

    //Revoking a transaction
    function revokeTx(uint256 _txId) public onlyOwners notExecuted(_txId) exists(_txId) isSigned(_txId) nonReentrant{
        signed[_txId][msg.sender] = false;
        txs[_txId]._approved -= 1;
        emit revoked(msg.sender, _txId); 
    }

}