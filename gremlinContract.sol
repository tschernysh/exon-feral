// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./gremlinToken.sol";
import "./h2oToken.sol";
import "./libraries/safeMath.sol";

import "./nftContracts/nft1.sol";
import "./nftContracts/nft2.sol";
import "./nftContracts/nft3.sol";
import "./nftContracts/nft4.sol";
import "./nftContracts/nft5.sol";
import "./nftContracts/nft6.sol";


contract GremlinContract {
  using SafeMath for uint256;

   H2oToken public h2oToken;
   GremlinToken public gremlinToken;

   GremlinNFTType1 public gremlinNFTType1;
   GremlinNFTType2 public gremlinNFTType2;
   GremlinNFTType3 public gremlinNFTType3;
   GremlinNFTType4 public gremlinNFTType4;
   GremlinNFTType5 public gremlinNFTType5;
   GremlinNFTTypeGem public gremlinNFTTypeGem;


  //  uint256 public day = 60 * 60 * 24;
   uint256 public day = 300;
   uint256 public boostPrice = 0.001 * 10**18;
   uint256 public bnbBalance = 0;
   uint256 public gremlinCurrency = 1000000000;

   uint256 public availableGremlinsToBuy = 0;

   mapping(address => address) public addressReferrals;

   mapping(address => uint256) public addressH2oCooldown;
   mapping(address => uint256) public addressBoostQuantity;
   mapping(uint256 => mapping(uint => uint256)) public tokensClaimCooldown;

   mapping(address => uint256) public referralBuyAmount;
   mapping(address => uint256) public withdrawnBuyAmount;

   mapping(address => uint256) public referralGremlinProfitAmount;
   mapping(address => uint256) public withdrawnGremlinProfitAmount;

   mapping(address => uint256) public referralH2oProfitAmount;
   mapping(address => uint256) public withdrawnH2oProfitAmount;

   mapping(address => uint256) public totalNftRewardGremlin;
   mapping(address => uint256) public totalNftRewardH2o;

   mapping(address => mapping(uint => uint256)) public addressReferralsByLevel;

   mapping(address => mapping(uint => uint256)) public addressBuyRefferalsByLevel;
   mapping(address => mapping(uint => uint256)) public addressEarnReferralsByLevel;

   address public defaultReferrer;

   uint[5] public buyReferralPercent = [
     7,
     5,
     3,
     3,
     2
   ];

   uint[7] public earnReferralPercent = [
     20,
     15,
     12,
     10,
     7,
     4,
     2
   ];

    uint[6] public dailyNftReward = [
      150000000,
      300000000,
      750000000,
      1500000000,
      3000000000,
      15000000000
    ];
    
    address private owner;

    address public nftContractAddress;
    address public h2oContractAddress;
    address public gremlinContractAddress;

    constructor(
      address _gremlinTokenAddress, 
      address _h2oTokenAddress, 
      address[] memory _nftContractAddresses, 
      address _defaultReferrer
    ){
      owner = msg.sender;

      gremlinToken = GremlinToken(_gremlinTokenAddress);

      h2oToken = H2oToken(_h2oTokenAddress);

      gremlinNFTType1 = GremlinNFTType1(_nftContractAddresses[0]);
      gremlinNFTType2 = GremlinNFTType2(_nftContractAddresses[1]);
      gremlinNFTType3 = GremlinNFTType3(_nftContractAddresses[2]);
      gremlinNFTType4 = GremlinNFTType4(_nftContractAddresses[3]);
      gremlinNFTType5 = GremlinNFTType5(_nftContractAddresses[4]);
      gremlinNFTTypeGem = GremlinNFTTypeGem(_nftContractAddresses[5]);
      
      defaultReferrer = _defaultReferrer;
    }

    modifier onlyOwner {
      require(
        msg.sender == owner , "Ownable: You are not the owner."
      );
        _;
    }

    event GetBoost(address indexed _to);
    event GetH2o(address indexed _to, uint256 _amount);
    event ClaimReferralBuy(address indexed _to, uint256 _amount);
    event ClaimReferralProfit(address indexed _to, uint256 _gremlinAmount, uint256 _h2oAmount);
    event SetUpliner(address indexed _referral, address indexed _upliner);
    event ChangedGremlinCurrency(uint256 _price);
    event ClaimNftReward(address indexed _to, uint256 _gremlinAmount, uint256 _h2oAmount);
    event BuyGremlins(address _to, uint256 _amount);

    function getBoost() payable public returns(string memory){
      require(msg.value == boostPrice, 'Not correct amount to get Boost');
      require(addressBoostQuantity[msg.sender] == 0, 'You already have active boost');

      addressBoostQuantity[msg.sender] = 5;

      emit GetBoost(msg.sender);
      return 'You successfuly bought boost. It will last for 5 claims';
    }

    function getAddressBuyRefferalsByLevel(address _address) public view returns(uint256[] memory _referralReward) {

      uint[] memory _referralRewardList = new uint[](5);

      for (uint i = 0; i < 5; i++) 
      {
        _referralRewardList[i] = addressBuyRefferalsByLevel[_address][i];
      }

      return _referralRewardList;
    }
    
    function getAddressEarnReferralsByLevel(address _address) public view returns(uint256[] memory _referralReward) {
       uint[] memory _referralRewardList = new uint[](7);

      for (uint i = 0; i < 7; i++) 
      {
        _referralRewardList[i] = addressEarnReferralsByLevel[_address][i];
      }

      return _referralRewardList;
    }

    function referralBuyRewardUpliner(address _currentAddress, uint _currentDepth, uint256 _boughtAmount) private {
      address currentUpliner = addressReferrals[_currentAddress];
      if (_currentAddress == defaultReferrer || currentUpliner == address(0)) return;

      addressBuyRefferalsByLevel[currentUpliner][_currentDepth] += _boughtAmount * buyReferralPercent[_currentDepth] / 100;

      if(_currentDepth == 5) return;

      uint nextDepth = _currentDepth+1;

      referralBuyRewardUpliner(currentUpliner, nextDepth, _boughtAmount);
    }

    function referralEarnRewardUpliner(address _currentAddress, uint _currentDepth, uint256 _gremlinProfitAmount) private {
      address currentUpliner = addressReferrals[_currentAddress];
      if (_currentAddress == defaultReferrer || currentUpliner == address(0)) return;

      if(_gremlinProfitAmount != 0){
        addressEarnReferralsByLevel[currentUpliner][_currentDepth] += _gremlinProfitAmount * earnReferralPercent[_currentDepth] / 100;
      }

      if(_currentDepth == 7) return;

      uint nextDepth = _currentDepth+1;

      referralEarnRewardUpliner(currentUpliner, nextDepth, _gremlinProfitAmount);
    }

    function buyGremlins() public payable returns(uint256){
      require( addressReferrals[msg.sender] != address(0),'You dont have upliner!');

      uint256 _bnbAmount = msg.value;

      uint256 gremlinsToMint = _bnbAmount.div(gremlinCurrency) * 10**18;

      uint256 currentAvailableGremlins = gremlinToken.balanceOf(address(this));

      require(gremlinsToMint <= currentAvailableGremlins, 'Not enough available GREMLINS to buy!');

      gremlinToken.transfer(msg.sender, gremlinsToMint);

      referralBuyRewardUpliner(msg.sender, 0, _bnbAmount);

      emit BuyGremlins(msg.sender, gremlinsToMint);
      return gremlinsToMint;
    }

    function getH2o() public returns(uint256){

      require( addressReferrals[msg.sender] != address(0),'You dont have upliner!');
      require((block.timestamp - addressH2oCooldown[msg.sender]) > day, 'H2O claim is in cooldown!');

      uint256 gremlinTokenBalance = gremlinToken.balanceOf(msg.sender);
      uint256 multiplier = addressBoostQuantity[msg.sender] != 0 ? 5 : 10;
      if(block.timestamp - addressH2oCooldown[msg.sender]  > day){
        h2oToken.mint(msg.sender, gremlinTokenBalance.div(multiplier));
        addressH2oCooldown[msg.sender] = block.timestamp;
        if(addressBoostQuantity[msg.sender] != 0){
          addressBoostQuantity[msg.sender] -= 1;
        }
      }

      emit GetH2o(msg.sender, gremlinTokenBalance.div(multiplier));
      return gremlinTokenBalance.div(multiplier);
    }

    function getAvailableGremlinNftReward(address _address) public view returns(uint256 availableAmount) {
      
      uint gremlinAmountMint = 0;

      for (uint i = 0; i < 6; i++) {

        uint256[] memory userNFTsArray = 
          i == 0
            ? gremlinNFTType1.getAddressNFTs(_address)
            : i == 1
              ? gremlinNFTType2.getAddressNFTs(_address)
              : i == 2
                ? gremlinNFTType3.getAddressNFTs(_address)
                : i == 3
                  ? gremlinNFTType4.getAddressNFTs(_address)
                  : i == 4
                    ? gremlinNFTType5.getAddressNFTs(_address)
                    : gremlinNFTTypeGem.getAddressNFTs(_address);

        for( uint j = 0; j < userNFTsArray.length; j++ ){

          uint currentNftId = userNFTsArray[j];

          if(currentNftId != 0){
            uint currentNftType = i;
            uint256 currentNftMintedTimestamp = getNftMintedtimestamp(currentNftType, currentNftId);
            if(block.timestamp - currentNftMintedTimestamp >= day){
              if(block.timestamp - tokensClaimCooldown[currentNftType][currentNftId] >= day){
                gremlinAmountMint += dailyNftReward[currentNftType];
              }
            }
          }
        }
      }

      return gremlinAmountMint;
    }

    function getAvailableH2oNftReward(address _address) public view returns(uint256 availableAmount) {
      
      uint h2oAmountMint = 0;

      for (uint i = 0; i < 6; i++) {

        uint256[] memory userNFTsArray = gremlinNFTTypeGem.getAddressNFTs(_address);

        for( uint j = 0; j < userNFTsArray.length; j++ ){

          uint currentNftId = userNFTsArray[j];

          if(currentNftId != 0){
            uint currentNftType = i;
            uint256 currentNftMintedTimestamp = getNftMintedtimestamp(currentNftType, currentNftId);
            if(block.timestamp - currentNftMintedTimestamp >= day){
              if(block.timestamp - tokensClaimCooldown[currentNftType][currentNftId] >= day){
                if(currentNftType == 5){
                  h2oAmountMint += dailyNftReward[currentNftType];
                }
              }
            }
          }
        }
      }

      return h2oAmountMint;
    }

    function claimNftReward() public returns(uint256 amount) {

      uint gremlinAmountMint = 0;
      uint h2oAmountMint = 0;

      for (uint i = 0; i < 6; i++) {

        uint256[] memory userNFTsArray = 
          i == 0
            ? gremlinNFTType1.getAddressNFTs(msg.sender)
            : i == 1
              ? gremlinNFTType2.getAddressNFTs(msg.sender)
              : i == 2
                ? gremlinNFTType3.getAddressNFTs(msg.sender)
                : i == 3
                  ? gremlinNFTType4.getAddressNFTs(msg.sender)
                  : i == 4
                    ? gremlinNFTType5.getAddressNFTs(msg.sender)
                    : gremlinNFTTypeGem.getAddressNFTs(msg.sender);

        for( uint j = 0; j < userNFTsArray.length; j++ ){

          uint currentNftId = userNFTsArray[j];

          if(currentNftId != 0){
            uint currentNftType = i;
            uint256 currentNftMintedTimestamp = getNftMintedtimestamp(currentNftType, currentNftId);
            if(block.timestamp - currentNftMintedTimestamp >= day){
              if(block.timestamp - tokensClaimCooldown[currentNftType][currentNftId] >= day){
              gremlinAmountMint += dailyNftReward[currentNftType];
              if(currentNftType == 5){
                h2oAmountMint += dailyNftReward[currentNftType];
              }
              tokensClaimCooldown[currentNftType][currentNftId] = block.timestamp;
            }
            }
          }
        }
      }

      if(gremlinAmountMint > 0){
        gremlinToken.mint(msg.sender, gremlinAmountMint * 10**18);
      }

      if(h2oAmountMint > 0) {
        h2oToken.mint(msg.sender, h2oAmountMint * 10**18);
      }

      referralEarnRewardUpliner(msg.sender, 0, gremlinAmountMint * 10**18);
      emit ClaimNftReward(msg.sender, gremlinAmountMint * 10**18, h2oAmountMint * 10**18);

      totalNftRewardGremlin[msg.sender] += gremlinAmountMint * 10**18;
      totalNftRewardH2o[msg.sender] += h2oAmountMint * 10**18;

      return gremlinAmountMint;
    }
    
    function changeGremlinCurrency(uint256 _newCurrency) onlyOwner public returns(uint256){
      gremlinCurrency = _newCurrency;
      emit ChangedGremlinCurrency(_newCurrency);
      return _newCurrency;
    }

    function getNftMintedtimestamp(uint256 _nftType, uint256 _nftId) public view returns(uint256){
       uint256 nftMintedTimestamp = 
          _nftType == 0
            ? gremlinNFTType1.mintTimestamp(_nftId)
            : _nftType == 1
              ? gremlinNFTType2.mintTimestamp(_nftId)
              : _nftType == 2
                ? gremlinNFTType3.mintTimestamp(_nftId)
                : _nftType == 3
                  ? gremlinNFTType4.mintTimestamp(_nftId)
                  : _nftType == 4
                    ? gremlinNFTType5.mintTimestamp(_nftId)
                    : gremlinNFTTypeGem.mintTimestamp(_nftId);

      return nftMintedTimestamp;
    }
     

    //function updateUplinersCounter(address _upliner, uint _depth) private {

      //address _newUpliner = addressReferrals[_upliner];
      //addressReferralsByLevel[_upliner][_depth] += 1;
      //addressReferrals[msg.sender] = _upliner;

      //if(_newUpliner == address(0)) return; 
      //if(_newUpliner == defaultReferrer) return; 
      //if(_depth == 7) return;

      //updateUplinersCounter(_newUpliner, _depth++);
    //}

    function setUpliner(address _upliner) public returns(address){
        require(addressReferrals[msg.sender] == address(0), 'You already have upliner!');

        addressReferrals[msg.sender] = _upliner;
        emit SetUpliner(msg.sender, _upliner);
        return _upliner;
    }

    function withdraw(address _to) payable public onlyOwner returns(uint256){
      payable(_to).transfer(address(this).balance);

      return address(this).balance;
    }

    function claimReferralBuyReward() public returns(uint256){

      uint256 totalReferralAmount = 0;

      address payable recipient = payable(msg.sender);

      for (uint i = 0; i < 5; i++) 
      {
        totalReferralAmount += addressBuyRefferalsByLevel[recipient][i];
      }

      require(totalReferralAmount - withdrawnBuyAmount[msg.sender] > 0 , 'You have nothing to withdraw.');
      
      recipient.transfer(totalReferralAmount);

      withdrawnBuyAmount[msg.sender] += totalReferralAmount;

      emit ClaimReferralBuy(msg.sender, totalReferralAmount - withdrawnBuyAmount[msg.sender]);
      return totalReferralAmount - withdrawnBuyAmount[msg.sender];
    }

    function claimReferralProfitReward() public returns(uint256[2] memory){

      uint256 totalReferralAmount = 0;

      for (uint i = 0; i < 7; i++) 
      {
        totalReferralAmount += addressEarnReferralsByLevel[msg.sender][i];
      }

      require(totalReferralAmount - withdrawnGremlinProfitAmount[msg.sender] > 0 , 'You have nothing to withdraw.');

      gremlinToken.mint(msg.sender, totalReferralAmount - withdrawnGremlinProfitAmount[msg.sender]);

      withdrawnGremlinProfitAmount[msg.sender] += totalReferralAmount;

      emit ClaimReferralProfit(
        msg.sender, 
        totalReferralAmount - withdrawnGremlinProfitAmount[msg.sender], 
        referralH2oProfitAmount[msg.sender] - withdrawnH2oProfitAmount[msg.sender]
      );
      return [totalReferralAmount - withdrawnGremlinProfitAmount[msg.sender], withdrawnH2oProfitAmount[msg.sender]];
    }

    function getAddressH2oCooldown(address _address) public view returns(uint256 _h2oCooldown) {

      return addressH2oCooldown[_address];
    }


    function getAddressBoostQuantity(address _address) public view returns(uint _boostQuantity) {
      return addressBoostQuantity[_address];
    }

    function getAvailableBuyReward(address _address) public view returns (uint256 _availableBuyReward) {
       uint256 totalReferralAmount = 0;

        for (uint i = 0; i < 5; i++) 
        {
          totalReferralAmount += addressBuyRefferalsByLevel[_address][i];
        }

        return totalReferralAmount - withdrawnBuyAmount[msg.sender];
    }

    function getAvailableEarnReward(address _address) public view returns (uint256 _availableBuyReward) {
       uint256 totalReferralAmount = 0;

        for (uint i = 0; i < 7; i++) 
        {
          totalReferralAmount += addressEarnReferralsByLevel[_address][i];
        }

        return totalReferralAmount - withdrawnGremlinProfitAmount[msg.sender];
    }

    function getAddressNftIds(address _address) public view returns(
      uint[] memory,uint[] memory,uint[] memory,uint[] memory,uint[] memory,uint[] memory
    ) {
      uint256[] memory userTokens1 = gremlinNFTType1.getAddressNFTs(_address);
      uint256[] memory userTokens2 = gremlinNFTType2.getAddressNFTs(_address);
      uint256[] memory userTokens3 = gremlinNFTType3.getAddressNFTs(_address);
      uint256[] memory userTokens4 = gremlinNFTType4.getAddressNFTs(_address);
      uint256[] memory userTokens5 = gremlinNFTType5.getAddressNFTs(_address);
      uint256[] memory userTokens6 = gremlinNFTTypeGem.getAddressNFTs(_address);
      
     
      return (userTokens1, userTokens2, userTokens3, userTokens4, userTokens5,userTokens6);
    }

    function depositGremlin(uint256 amount) external onlyOwner returns(uint256 _amount) {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from the user to the smart contract
        gremlinToken.transferFrom(msg.sender, address(this), amount);

        availableGremlinsToBuy += amount;

        return amount;
    }
}
