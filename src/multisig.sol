//SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

contract multiSigWallet {

    mapping(address=>bool) public isValidSigner;
    mapping(address=>uint256) public ethBalances;
    mapping(address=>mapping(address=>uint256)) tokenBalances;

    address[] owners;
    uint256 public minRequired;

    event deposited(address indexed sender, uint256 indexed amount);
    event approved(address indexed signer, uint256 txId);
    event revoked(address indexed signer, uint256 txId);
    event executed(address indexed signer, uint256 txId);
    event submited(address indexed signer, uint256 txId);

    constructor(address[] memory _signers, uint256 _minRequired)
    {
        for(uint256 i = 0; i < _signers.length; i++){
            require(isValidSigner[_signers[i]] == false, "duplicate signer");
            isValidSigner[_signers[i]] = true;
            owners.push(_signers[i]);
        }
        minRequired = _minRequired;
    }

    function Deposit() public payable{
        ethBalances[msg.sender] += msg.value;
        emit deposited(msg.sender, msg.value);
    }

    function withdrawETH(uint256 ethAmount) public payable{
        require(ethAmount <= ethBalances[msg.sender], "not enough eth balance"); 
        ethBalances[msg.sender] -= ethAmount;
        
    }

}