// SPDX-License-Identifier: RAN
pragma solidity >=0.4.22 <0.9.0;

// pragma solidity ^0.7.4;

contract HeymateEscrows {
    address public owner;
    bytes32 public tradeHash;
    uint256 public cancellationValueDeposit;
    uint256 public delayCompensation;
    uint256 public releaseAmount;
    uint256 public totalFees;
    uint256 public feesAvailableForWithdraw;

    event Created(bytes32 _tradeHash);
    event StartService(bytes32 _tradeHash);
    event Released(bytes32 _tradeHash);
    event CancelledByServiceProvider(bytes32 _tradeHash);
    event CancelledByConsumer(bytes32 _tradeHash);
    
    // To remove
    enum State{ TRADE_INITIALIZED, INITIAL_PAYMENT_RECEIVED, SERVICE_START,
    SERVICE_CANCELLED_BY_SP, SERVICE_CANCELLED_BY_CS, SERVICE_COMPLETE }
        

     struct Offer {
        bool exists;
        uint32 serviceStartTime;
        uint256 initialDepositValue;
        uint256 remainingValue;
        uint32 slotTime;
        uint32 tradeStartTime;
        uint32 cancelHourVar1;
        uint32 cancelHourVar1Percen;
        uint32 cancelHourVar2;
        uint32 cancelHourVar2Percen;
        uint16 delayHour;
        uint16 delayHourPercen;
        State currentState;
    }
    
    // Mapping of active trades. Key is a hash of the trade data
    mapping (bytes32 => Offer) public offers;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    constructor() public {
        owner = msg.sender;
    }
    
    // Get the offer details
     function getOfferAndHash(
      bytes16 _tradeID,
      address _serviceProvider,
      address _consumer,
      uint256 _amount,
      uint16 _fee
    ) view private returns (Offer storage, bytes32) {
        bytes32 _tradeHash = keccak256(abi.encodePacked(_tradeID, _serviceProvider, _consumer, _amount, _fee));
        return (offers[_tradeHash], _tradeHash);
    }

    // Creating offer - Trade between service provider and consumer
    
    function createOffer(
      bytes16 _tradeID, 
      address payable _serviceProvider, 
      address _consumer,
      uint256 _amount, 
      uint16 _fee, 
      uint32 _expiry,
      uint32 _slotTime,
      uint256 _initialDeposit,
      uint32 _cancelHourVar1,
      uint16 _cancelHourVar1Percen,
      uint32 _cancelHourVar2,
      uint16 _cancelHourVar2Percen,
      uint16 _delayHour,
      uint16 _delayHourPercen
      
    ) payable external  {
        bytes32 _tradeHash = keccak256(abi.encodePacked(_tradeID, _serviceProvider, _consumer, _amount, _fee));
        require(!offers[_tradeHash].exists, "Trade already exist");
        require(block.timestamp < _expiry, "Offer expired!");
        uint32 tradeStartTime = uint32(block.timestamp);
        require(msg.value == _amount && msg.value > 0, "Amount send should be equal to the signed value and should be greater than Zero"); // Check sent eth against signed _value and make sure is not 0
        
        if (_cancelHourVar1 > 0){
          _cancelHourVar1 = tradeStartTime +  _cancelHourVar1 * 60 * 60;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
        }
        
        if(_cancelHourVar2 > 0){
         _cancelHourVar2 = _cancelHourVar1 + _cancelHourVar2 * 60 * 60;
        }
        
         if(_delayHour> 0){
         _delayHour = _delayHour * 60 * 60;
        }
        
        offers[_tradeHash] = Offer(true, 0, 0, 0, _slotTime, tradeStartTime, _cancelHourVar1, _cancelHourVar1Percen,
        _cancelHourVar2, _cancelHourVar2Percen, _delayHour, _delayHourPercen, State.TRADE_INITIALIZED );
        
        tradeHash = _tradeHash;
        
        
        if(_initialDeposit > 0) {

            offers[_tradeHash].initialDepositValue = getInitialDeposit(_amount, _initialDeposit) ;
            offers[_tradeHash].remainingValue = _amount - offers[_tradeHash].initialDepositValue;
            offers[_tradeHash].currentState = State.INITIAL_PAYMENT_RECEIVED;
            
            transferMinusFees(_serviceProvider, offers[_tradeHash].initialDepositValue , _fee);
         }
         
        emit Created(_tradeHash);
    }
    
    
    function getInitialDeposit(uint256 _amount, uint256 _initialDeposit) private pure returns (uint256) {
         uint256 _initialDepositValue =  (_amount * _initialDeposit / 100);
            return _initialDepositValue;
    }
   
    // Start service function. Only SP can start the service.
     function dostartService(
      bytes16 _tradeID,
      address _serviceProvider,
      address _consumer,
      uint256 _amount,
      uint16 _fee
    ) private returns (bool) {
        (Offer memory _offer, bytes32 _tradeHash) = getOfferAndHash(_tradeID, _serviceProvider, _consumer, _amount, _fee);
        
        if (!_offer.exists) return false;
        require(_offer.currentState == State.TRADE_INITIALIZED || _offer.currentState == State.INITIAL_PAYMENT_RECEIVED  , "Not in 'TRADE_INITIALIZED' or 'INITIAL_PAYMENT_RECEIVED' state");
        
        uint32 _serviceStartTime =  uint32(block.timestamp);
        offers[_tradeHash].serviceStartTime = _serviceStartTime;
        offers[_tradeHash].currentState = State.SERVICE_START;

        emit  StartService(_tradeHash);
        return true;
    }
    
   
    
    // Consumer call this function to release remaining money and mark the service as Complete.
    function doRelease(
      bytes16 _tradeID,
      address payable _serviceProvider,
      address payable _consumer,
      uint256 _amount,
      uint16 _fee
    ) private returns (bool) {
       (Offer memory _offer, bytes32 _tradeHash) = getOfferAndHash(_tradeID, _serviceProvider, _consumer, _amount, _fee);

        if (!_offer.exists) return false;
        require(offers[_tradeHash].currentState == State.SERVICE_START, "Not 'SERVICE_START' state");
         
        uint256 _delayCompensationValue;
        if(offers[_tradeHash].serviceStartTime > offers[_tradeHash].slotTime + offers[_tradeHash].delayHour )   {
         _delayCompensationValue = (_amount * offers[_tradeHash].delayHourPercen / 100);
         delayCompensation = _delayCompensationValue;
         transferMinusFees(_consumer, _delayCompensationValue, _fee);
        }

        uint256 _releaseAmount = offers[_tradeHash].remainingValue - _delayCompensationValue;
        releaseAmount = _releaseAmount;
      
        emit Released(_tradeHash);
        transferMinusFees(_serviceProvider, _releaseAmount, _fee);
        offers[_tradeHash].currentState = State.SERVICE_COMPLETE;
        delete offers[_tradeHash];
        return true;
    }
    
    // SP can cancel the service.
    function doServiceProviderCancel(
      bytes16 _tradeID,
      address _serviceProvider,
      address payable _consumer,
      uint256 _amount,
      uint16 _fee
    ) private returns (bool) {
        (Offer memory _offer, bytes32 _tradeHash) = getOfferAndHash(_tradeID, _serviceProvider, _consumer, _amount, _fee);
       
        if (!_offer.exists) return false;
        if(offers[_tradeHash].currentState == State.SERVICE_START) return false;

        emit CancelledByServiceProvider(_tradeHash);
        releaseAmount = offers[_tradeHash].remainingValue;
        transferMinusFees(_consumer, offers[_tradeHash].remainingValue, _fee);
        offers[_tradeHash].currentState = State.SERVICE_CANCELLED_BY_SP;
        delete offers[_tradeHash];
        return true;
    }
    
    // Consumer can cancel the service. 
    function doConsumerCancel(
      bytes16 _tradeID,
      address payable _serviceProvider,
      address payable _consumer,
      uint256 _amount,
      uint16 _fee
    ) private returns (bool) {
        (Offer memory _offer, bytes32 _tradeHash) = getOfferAndHash(_tradeID, _serviceProvider, _consumer, _amount, _fee);
        if (!_offer.exists) return false;
        if(offers[_tradeHash].currentState == State.SERVICE_START) return false;
        
        uint256 _cancellationValueDeposit = 0;
        uint32 cancelTime =  uint32(block.timestamp);
        
        if(cancelTime > offers[_tradeHash].tradeStartTime  && cancelTime <= offers[_tradeHash].cancelHourVar1){
              _cancellationValueDeposit = offers[_tradeHash].remainingValue * offers[_tradeHash].cancelHourVar1Percen / 100;
               cancellationValueDeposit = _cancellationValueDeposit;
               transferMinusFees(_serviceProvider, _cancellationValueDeposit, _fee);
        }
         
        else if(cancelTime > offers[_tradeHash].cancelHourVar1 && cancelTime <= offers[_tradeHash].cancelHourVar2 ){
              _cancellationValueDeposit = offers[_tradeHash].remainingValue *  offers[_tradeHash].cancelHourVar2Percen / 100;
               cancellationValueDeposit = _cancellationValueDeposit;
               transferMinusFees(_serviceProvider, _cancellationValueDeposit, _fee);
        }
         
       
        uint256 _releaseAmount = offers[_tradeHash].remainingValue - _cancellationValueDeposit;
        releaseAmount = _releaseAmount;
      
        emit CancelledByConsumer(_tradeHash);
        transferMinusFees(_consumer,  _releaseAmount, _fee);
        offers[_tradeHash].currentState = State.SERVICE_CANCELLED_BY_CS;
        delete offers[_tradeHash];
        return true;
    }
  
    
      function startService(bytes16 _tradeID, address _serviceProvider, address _consumer, uint256 _amount, uint16 _fee) external returns (bool){
      require(msg.sender == _serviceProvider, "Not Service provider");
      return dostartService(_tradeID,  _serviceProvider, _consumer, _amount, _fee);
    }
    
    
     function release(bytes16 _tradeID, address payable _serviceProvider, address payable _consumer, uint256 _amount, uint16 _fee) external payable returns (bool){
     require(msg.sender == _consumer, "Not Consumer");
     return doRelease(_tradeID, _serviceProvider, _consumer, _amount, _fee);
    }
    
    
     function consumerCancel(bytes16 _tradeID, address payable _serviceProvider, address payable _consumer, uint256 _amount, uint16 _fee) external returns (bool) {
     require(msg.sender == _consumer, "Not Consumer");
     return doConsumerCancel(_tradeID, _serviceProvider, _consumer, _amount, _fee);
    }
    
      function serviceProviderCancel(bytes16 _tradeID, address _serviceProvider, address payable _consumer, uint256 _amount, uint16 _fee) external returns (bool) {
      require(msg.sender == _serviceProvider, 'Not Service provider');
      return doServiceProviderCancel(_tradeID, _serviceProvider, _consumer, _amount, _fee);
    }
    
     function transferMinusFees(address payable  _to, uint256 _amount, uint16 _fee) private {
        uint256 _totalFees = (_amount * _fee / 10000);
        totalFees = _totalFees;
        if(_amount - _totalFees > _amount) return; // Prevent underflow
        feesAvailableForWithdraw += _totalFees; 
        _to.transfer(_amount - _totalFees);
    }
    
     function withdrawFees(address payable _to, uint256 _amount) onlyOwner external {
        require(_amount <= feesAvailableForWithdraw); // Prevents underflow
        feesAvailableForWithdraw -= _amount;
        _to.transfer(_amount);
    }
    
      function setOwner(address _newOwner) onlyOwner external {
        owner = _newOwner;
    }
}

