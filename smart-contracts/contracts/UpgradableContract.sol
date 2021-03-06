//SPDX-License-Identifier: MIT
//Following Open Zeppelins' solc version control - hopefully the code works.
//Let's go with solc 0.8.0 in the compile to try and optimize longevity.
pragma solidity >=0.7.0;

//Trying to follow along with Open Zeppelin's docs

// to do: put in Open-Zeppelin libraries for:
// pause functionality (Pausable)
// initialize functionality (Initializable)
// proxy admin?
// is there an admin?

//import "@openzeppelin/upgrades/contracts/Initializable.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/pausableupgradeable.sol";

import "./provableAPI_0.6.sol";

contract DogDiceDAOGame is Initializable, PausableUpgradeable, usingProvable {

    //pattern  as per 
    //@filipmartinsson/Smart-Contract-Security/blob/master/Upgradeable-Advanced/contracts/Storage.sol

    mapping (string => uint256) _uintMapping;
    mapping (string => address ) _addressMapping;
    mapping (string => bool ) _boolMapping;
    mapping (string => string) _stringMapping;
    mapping (string => bytes32 ) _bytesMapping;
    mapping (address => uint256) _balanceMapping;
    
    //The below was the intended implementation but apparently structs have issues
    //(OpenZeppelin spittiing out ominous error messages re upgradeable contract memory).
    // struct Match {
    //     bool finished;
    //     bytes32 id;
    //     address player;
    //     uint256 staked_amount;
    //     bool won;
    // }
    // mapping (bytes32 => Match) _matchMapping;
    
    //So let's explode the mapping instead:

    mapping (bytes32 => bool) _matchFinishedMapping;
    mapping (bytes32 => address) _matchPlayerMapping;
    mapping (bytes32 => uint256) _matchStakeMapping;
    mapping (bytes32 => bool) _matchWonMapping;

    //address  owner;

    function initialize() public initializer {
        // Depending on how the OpenZeppelin deployment works the below
        // is to be removed or reinstated.
        //owner = msg.sender;
        _addressMapping["initializer"] = msg.sender;
        _uintMapping["latestRandomNumber"] = 0;
        _uintMapping["previousRandomNumber"] = 0;
        _uintMapping["MAX_INT_FROM_BYTE"] = 256;
        _uintMapping["NUM_RANDOM_BYTES_REQUESTED"] = 1;

    }

    // Functions this game contract should have:
    // 1)Random function call routine.
    // 2)Check whether a game resulted in a win or loss.
    // 3)In the future, this will be upgradeable to specifically check if one of two
    //  players won or lost so the code must reflect this forward-compatiility.
    // 4)Store user accounts and associated balances.
    // 5)Store user accounts and any associated tokens.
    // 6)Store user accounts and any associated NFTs.
    // 7)Get user accounts and associated balances.
    // 8)Get user accounts and any associated tokens.
    // 9)Get user accounts and any associated NFTs.
    // 10)Associated indexed events.
    // 11)Governance contract can be a contract upgrade or an entirely different contract.

    // 1)Random function call routine.
    // -Implementation will use Provable Things as per Filip's tutorial in Ivan's Academy:
    //https://github.com/filipmartinsson/solidity-201/blob/master/oracle-contract/contract.sol
    
    // _uintMapping["MAX_INT_FROM_BYTE"] = 256;
    // _uintMapping["NUM_RANDOM_BYTES_REQUESTED"] = 1;
    // _uintMapping["previousRandomNumber"] = 0;
    // _uintMapping["latestRandomNumber"] = 0;
    // _uintMapping["randomNumberCeiling"] = 2;//initializer is handling these
    
    //the following events are borrowed from  lohba/Coin-Flip-Dapp-v2 on Github:
    event LogNewProvableQuery(string description);
    event generatedRandomNumber(uint256 randomNumber);
    event resultOutcome(address player, bool won, uint256 playerBalance);
    

    function __callback(bytes32 _queryId, string memory _result, bytes memory _proof) public override
    {
        require(msg.sender == provable_cbAddress());

        _uintMapping["previousRandomNumber"] = _uintMapping["latestRandomNumber"];
        _uintMapping["latestRandomNumber"] = uint256(keccak256(abi.encodePacked(_result)))
                                                % _uintMapping["randomNumberCeiling"];
        emit generatedRandomNumber( _uintMapping["latestRandomNumber"]);
        processGameResult(_uintMapping["latestRandomNumber"], _queryId);
                                            
    }
    
    function updateRandomNumber(address _player, uint256 _stake) payable public
    {
        _uintMapping["QUERY_EXECUTION_DELAY"] = 0;
        _uintMapping["GAS_FOR_CALLBACK "] = 200000;
        bytes32 _id = provable_newRandomDSQuery(
                                    _uintMapping["QUERY_EXECUTION_DELAY"],
                                    _uintMapping["NUM_RANDOM_BYTES_REQUESTED"],
                                    _uintMapping["GAS_FOR_CALLBACK "]
                                );
        // _matchMapping[_id].id = _id;
        // _matchMapping[_id].player = _player;
        // _matchMapping[_id].staked_amount = _stake;
        // _matchMapping[_id].won = false;
        // _matchMapping[_id].finished = false;
        _matchPlayerMapping[_id] = _player;
        _matchStakeMapping[_id] = _stake;
        _matchWonMapping[_id] = false;
        _matchFinishedMapping[_id] = false;
        
        emit LogNewProvableQuery("Provable Query sent...");

    }
    
    
    // 2)Check whether a game resulted in a win or loss.
    
    function playGame(uint256 _stake) public payable
    {
        require(_stake <= _balanceMapping[msg.sender], "Insufficient balance!");
        _balanceMapping[msg.sender] -= _stake;
        _stake += msg.value; 
        _stake -= _uintMapping["GAS_FOR_CALLBACK "];
        require( _stake > 0, "Not enough eth for Oracle Query gas and game" );
        updateRandomNumber(msg.sender, _stake); //Assuming that the gas is simply drawn from the contract address.
    }

    function processGameResult(uint256 _numberReceived, bytes32 _gameId) private
    {
        _matchFinishedMapping[_gameId] = true;
        bool won = checkWinCondition(_numberReceived);
        if (won && _matchFinishedMapping[_gameId])
        {
            _matchWonMapping[_gameId] = true;
            _balanceMapping[_matchPlayerMapping[_gameId]] +=
                            _matchStakeMapping[_gameId];   
        }
    }

    function checkWinCondition(uint256 _numberReceived) private pure returns (bool) 
    {   
        bool result = _numberReceived % 2 == 1;
        return result;
    }

    // 3)In the future, this will be upgradeable to specifically check if one of two
    //  players won or lost so the code must reflect this forward-compatiility.
    //  -Here there just needs to be further workings on sockets, concurrency etc to prevent
    //   too random number calls for one multiplayer game.

    // 4)Store user accounts and associated balances.
    // 5)Store user accounts and any associated tokens.
    // 6)Store user accounts and any associated NFTs.

    // Initial implementation: simple deposit to user balance, all txns in Eth.

    function depositEth () public payable
    {
        require(msg.value>0, "Non-zero deposit needed.");
        _balanceMapping[msg.sender] += msg.value;
    }

    function withdrawEth (uint256 _withdrawalAmount) public
    {
        _balanceMapping[msg.sender] -= _withdrawalAmount;
        msg.sender.transfer( _withdrawalAmount) ;
    }


    // 7)Get user accounts and associated balances.
    // 8)Get user accounts and any associated tokens.
    // 9)Get user accounts and any associated NFTs.

    // Initial implementation: deposits and balances only in Eth.

    function getBalance() public view returns (uint256)
    {
        return _balanceMapping[msg.sender];
    }

    //Further considerations:
    // 10)Associated indexed events.
    // 11)Governance contract can be a contract upgrade or an entirely different contract.












}



