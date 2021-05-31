// SPDX-License-Identifier: HEYMATE
// Deployed Address on 31st May 2021 - 0x7C75b8FF4Efa13190a062723159b21a1460d291B
// Updated with Pricing plans - Bundles and Sunscriptions // 31st May    

// SPDX-License-Identifier: HEYMATE

pragma solidity ^0.7.4;

/**
@notice Celo Escrow contract is used to transfer tokens to the referrers 
who are non-heymate users.

@dev When the consumer buys the offer, the referral bonus is transferred. If the referrers are 
not in the Heymate platform, we will transfer the tokens to the Celo escrow contract and lateron,
users can claim it. 
 */
contract celoEscrowContract {
    function transfer(
        bytes32 identifier,
        address token,
        uint256 value,
        uint256 expirySeconds,
        address payable paymentId,
        uint256 minAttestations
    ) public returns (bool) {}
}
 
/**
@notice Celo stableToken contract is for transferring the tokens to users.
@dev approve function lets msg.sender to approve the escrow contract to transfer (EscrowTransfer)
 */
contract celoStableTokenContract {
     function transfer(address to, uint256 value) public returns (bool) {}
     function approve(address spender, uint256 value) public virtual returns (bool) {}
}

/**
@notice Heymate Contract 
 */
contract HeymateOffer {
    address public owner;
    address public serviceProvider;
    address public consumer;
    bytes32 public tradeHash;
    uint256 public cancellationValueDeposit;
    uint256 public delayCompensation;
    uint256 public releaseAmount;
    uint256 public totalFees;
    uint256 public feesAvailableForWithdraw;
    
    bytes32 public planHash;
    
    event Created(bytes32 _tradeHash);
    event StartService(bytes32 _tradeHash);
    event Released(bytes32 _tradeHash);
    event CancelledByServiceProvider(bytes32 _tradeHash);
    event CancelledByConsumer(bytes32 _tradeHash);
    
    event CreatedPlan(bytes32 _planHash);

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
        uint32 delayHour;
        uint32 delayHourPercen;
        uint256 rewardValue;
    }

    struct offerInfo {
        uint256 _amount;
        bytes16 _planID;
        address serviceProvider;
        address consumer;
    }
    
    struct Plan {
        bool exists;
        uint planType;   // BundleId /SubscriptionId
        uint amountPerSession;
        uint subScriptionType;
        uint totalBundles;
        uint availableBundles;
    }
 
    // Mapping of active trades. Key is a hash of the trade data
    mapping(bytes32 => Offer) public offers;

    mapping(bytes32 => Plan) public plans;

     modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    constructor() {
    owner = msg.sender;
    }

    // Celo deployed contract address for Escrow and StableToken
    address stableTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;
    address celoEscrowContractAddress = 0xb07E10c5837c282209c6B9B3DE0eDBeF16319a37;
    
     // Escrow transfer for non-heymate users.
    function escrowTransfer(
        bytes32 identifier,
        address payable token,
        uint256 value,
        uint256 expirySeconds,
        address payable paymentId,
        uint256 minAttestations
    ) public payable returns (bool) {
        celoEscrowContract c = celoEscrowContract(celoEscrowContractAddress);

        return
            c.transfer(
                identifier,
                token,
                value,
                expirySeconds,
                paymentId,
                minAttestations
            );
    }
  
    // Get the offer details
    function getOfferAndHash(
        bytes16 _tradeID,
        address _serviceProvider,
        address _consumer,
        uint256 _amount,
        uint16 _fee
    ) private view returns (Offer storage, bytes32) {
        bytes32 _tradeHash =
            keccak256(
                abi.encodePacked(
                    _tradeID,
                    _serviceProvider,
                    _consumer,
                    _amount,
                    _fee
                )
            );
        return (offers[_tradeHash], _tradeHash);
    }
    
    // Celo contract to transfer tokens
     function transferAmount(address  to, uint256 value) public returns (bool) {
        celoStableTokenContract obj = celoStableTokenContract(stableTokenAddress);
        return obj.transfer(
                to,
                value
            );
    }

    // Celo contract to approve
    function approveTransfer(address spender, uint256 value) public virtual returns (bool) {
        celoStableTokenContract obj = celoStableTokenContract(stableTokenAddress);
        return obj.approve(spender,value);
    }
    
    
    // Creating Plans 

    /**
    config[0] - _amountPerSession
    config[1] - _subScriptionType     // 1- Monthly , 2 - Yearly
    config[2] - _totalBundles
    config[3] - _referralConfigId 
    confid[4] - _referrerPercen  
     */
     
    
    function createPlan(
        bytes16 _planID, 
        uint _planType,  // Bundles / Subscription
        uint [] memory config,
        address payable[] memory userAddress,
        bytes memory signature
    ) external  { 
        bytes32 _planHash =
            keccak256(abi.encodePacked(_planID,userAddress[0],userAddress[1])); 
        // Signature verification 
        bytes32 _msgHash =  keccak256(abi.encodePacked(userAddress[0], config[0],config[1]));
        bytes32 ethSignedMessageHash = prefixed(_msgHash);
        // require(recoverSigner(ethSignedMessageHash, signature) == userAddress[0], "Wrong signature");
        plans[_planHash] = Plan(true, _planType, config[0] , config[1],  config[2] ,  config[2]);
        planHash = _planHash;
        emit CreatedPlan(_planHash);
        
    }

    // Creating offer - Trade between service provider and consumer

    /**
     * userAddress[0]       - Service provider
     * userAddress[1]       - Consumer
     * config[0]            - _cancelHourVar1
     * config[1]            - _cancelHourVar1Percen
     * config[2]            - _cancelHourVar2
     * config[3]            - _cancelHourVar2Percen
     * config[4]            - _delayHour
     * config[5]            - _delayHourPercen
     * config[6]            - _referralConfigId , 1 - FirstInteraction , 2 -> Last interaction . 3-> Last No-Direct click 4 -> Linear
     * config[7]            - _referralConfigPercen
     *
     *
     **/

    function createOffer(
        bytes16 _tradeID,
        bytes16 _planID,
        uint256 _amount,
        uint16 _fee,
        uint32 _expiry,
        uint32 _slotTime,
        uint256 _initialDeposit,
        address payable[] memory userAddress,
        uint32[] memory config,
        address payable[] memory activeReferrers,
        address payable[] memory newReferrers,
        bytes memory signature
    ) external payable {
        bytes32 _tradeHash =
            keccak256(
                abi.encodePacked(
                    _tradeID,
                    userAddress[0],
                    userAddress[1],
                    _amount,
                    _fee
                )
            );
        require(!offers[_tradeHash].exists, "Trade already exist");
        require(block.timestamp < _expiry, "Offer expired!");
        uint32 tradeStartTime = uint32(block.timestamp);
        uint256 _rewardValue;
        uint256 _rewardPerReferrer;
        
        offerInfo memory offerinfo;
        offerinfo._amount = _amount;
        offerinfo._planID = _planID;
        offerinfo.serviceProvider = userAddress[0];
        offerinfo.consumer = userAddress[1];
       
        // require(msg.sender == userAddress[1], "Not consumer");
        
        // this recreates the message that was signed on the client

        bytes32 _msgHash =  keccak256(abi.encodePacked(userAddress[0], offerinfo._amount, _initialDeposit , config));
        bytes32 ethSignedMessageHash = prefixed(_msgHash);

        // require(recoverSigner(ethSignedMessageHash, signature) == userAddress[0], "Wrong signature");
        
        { // To avoid stack too deep error
            (Plan memory _plan, bytes32 _planHash)= getPlanAndHash(offerinfo._planID, offerinfo.serviceProvider, offerinfo.consumer);
                if (_plan.exists == true) {
                    require( plans[_planHash].availableBundles > 0 , "No available bundles.");
                    planHash = _planHash;
                    plans[_planHash].availableBundles -= 1;
                }
        }
        
        if (config[0] > 0) {
            config[0] = tradeStartTime + config[0] * 60;
        }

        if (config[2] > 0) {
            config[2] = config[0] + config[2] * 60;
        }

        if (config[4] > 0) {
            config[4] = config[4] * 60;
        }

        // Referral bonus calculation
        if (config[6] == 4){
            if(config[7] > 0){
                _rewardValue = offerinfo._amount * config[7] / 100;
                offerinfo._amount = offerinfo._amount - _rewardValue;
                
                uint totalReferrers = activeReferrers.length + newReferrers.length;
                _rewardPerReferrer = _rewardValue / totalReferrers;
            }
        }
        
       // Distributing the referral bonus for the heymate users
        if(activeReferrers.length > 0){
            for (uint i=0; i< activeReferrers.length ; i++){
                 transferAmount(activeReferrers[i], _rewardPerReferrer);
            }
        }
        
        // Creating escrow payment for the non-heymate users in celo
        if(newReferrers.length > 0){
            approveTransfer(celoEscrowContractAddress, _rewardPerReferrer * newReferrers.length );
             for (uint i=0; i< newReferrers.length ; i++){
                 escrowTransfer('0x0',
                    0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1,    // Stable Token address
                    _rewardPerReferrer,
                    604800,                     // 7 days in seconds
                    newReferrers[i],
                    0);
             }
        }
        
        offers[_tradeHash] = Offer(
            true,
            0,
            0,
            0,
            _slotTime,
            tradeStartTime,
            config[0],
            config[1],
            config[2],
            config[3],
            config[4],
            config[5],
            _rewardValue
        );

        tradeHash = _tradeHash;

        if (_initialDeposit > 0) {
            offers[_tradeHash].initialDepositValue = getInitialDeposit(
                offerinfo._amount,
                _initialDeposit
            );
            offers[_tradeHash].remainingValue =
                offerinfo._amount -
                offers[_tradeHash].initialDepositValue;
           
             transferAmount(
              userAddress[0],
              offers[_tradeHash].initialDepositValue
              );
        }

        emit Created(_tradeHash);
    }

    // Creates the hash.
    function prefixed(bytes32 hash) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    //signature methods.
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        // require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function getInitialDeposit(uint256 _amount, uint256 _initialDeposit)
        private
        pure
        returns (uint256)
    {
        uint256 _initialDepositValue = ((_amount * _initialDeposit) / 100);
        return _initialDepositValue;
    }
    
       // Get the plan details
    function getPlanAndHash(
        bytes16 _planID,
        address _serviceProvider,
        address _consumer
    ) private view returns (Plan storage, bytes32) {
        bytes32 _planHash =
            keccak256(
                abi.encodePacked(
                    _planID,
                    _serviceProvider,
                    _consumer
                )
            );
        return (plans[_planHash], _planHash);
    }

    

    // Start service function. Only SP can start the service.
    function dostartService(
        bytes16 _tradeID,
        address _serviceProvider,
        address _consumer,
        uint256 _amount,
        uint16 _fee
    ) private returns (bool) {
        (Offer memory _offer, bytes32 _tradeHash) =
            getOfferAndHash(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );

        if (!_offer.exists) return false;
        uint32 _serviceStartTime = uint32(block.timestamp);
        offers[_tradeHash].serviceStartTime = _serviceStartTime;
        emit StartService(_tradeHash);
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
        (Offer memory _offer, bytes32 _tradeHash) =
            getOfferAndHash(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );

        if (!_offer.exists) return false;

        uint256 _delayCompensationValue;
        if (
            offers[_tradeHash].serviceStartTime >
            offers[_tradeHash].slotTime + offers[_tradeHash].delayHour
        ) {
            _delayCompensationValue = ((_amount *
                offers[_tradeHash].delayHourPercen) / 100);
            delayCompensation = _delayCompensationValue;
            transferMinusFees(_consumer, _delayCompensationValue, _fee);
        }

        uint256 _releaseAmount =
            offers[_tradeHash].remainingValue - _delayCompensationValue;
        releaseAmount = _releaseAmount;

        emit Released(_tradeHash);
        transferMinusFees(_serviceProvider, _releaseAmount, _fee);
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
        (Offer memory _offer, bytes32 _tradeHash) =
            getOfferAndHash(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );

        if (!_offer.exists) return false;
        emit CancelledByServiceProvider(_tradeHash);
        releaseAmount = offers[_tradeHash].remainingValue;
        transferMinusFees(_consumer, offers[_tradeHash].remainingValue, _fee);
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
        (Offer memory _offer, bytes32 _tradeHash) =
            getOfferAndHash(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );
        if (!_offer.exists) return false;
        uint256 _cancellationValueDeposit = 0;
        uint32 cancelTime = uint32(block.timestamp);

        if (
            cancelTime > offers[_tradeHash].tradeStartTime &&
            cancelTime <= offers[_tradeHash].cancelHourVar1
        ) {
            _cancellationValueDeposit =
                (offers[_tradeHash].remainingValue *
                    offers[_tradeHash].cancelHourVar1Percen) /
                100;
            cancellationValueDeposit = _cancellationValueDeposit;
            transferMinusFees(
                _serviceProvider,
                _cancellationValueDeposit,
                _fee
            );
        } else if (
            cancelTime > offers[_tradeHash].cancelHourVar1 &&
            cancelTime <= offers[_tradeHash].cancelHourVar2
        ) {
            _cancellationValueDeposit =
                (offers[_tradeHash].remainingValue *
                    offers[_tradeHash].cancelHourVar2Percen) /
                100;
            cancellationValueDeposit = _cancellationValueDeposit;
            transferMinusFees(
                _serviceProvider,
                _cancellationValueDeposit,
                _fee
            );
        }

        uint256 _releaseAmount =
            offers[_tradeHash].remainingValue - _cancellationValueDeposit;
        releaseAmount = _releaseAmount;

        emit CancelledByConsumer(_tradeHash);
        transferMinusFees(_consumer, _releaseAmount, _fee);
        delete offers[_tradeHash];
        return true;
    }
    
     function doSubscriptionPayment(
        bytes16 _planID,
        address  _serviceProvider,
        address payable _consumer
    ) private returns (bool) {
       
            (Plan memory _plan, bytes32 _planHash)= getPlanAndHash(_planID, _serviceProvider, _consumer);
             if (_plan.exists == true) {
                      transferAmount(_serviceProvider, plans[_planHash].amountPerSession);
                }
        return true;
    }
    
    
    function doCancelSubscription(
        bytes16 _planID,
        address  _serviceProvider,
        address payable _consumer
    ) private returns (bool) {
       
            (Plan memory _plan, bytes32 _planHash)= getPlanAndHash(_planID, _serviceProvider, _consumer);
               if (!_plan.exists) return false;
             delete plans[_planHash];
             return true;
    }


    function startService(
        bytes16 _tradeID,
        address _serviceProvider,
        address _consumer,
        uint256 _amount,
        uint16 _fee
    ) external returns (bool) {
        // require(msg.sender == _serviceProvider, "Not Service provider");
        return
            dostartService(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );
    }

    function release(
        bytes16 _tradeID,
        address payable _serviceProvider,
        address payable _consumer,
        uint256 _amount,
        uint16 _fee
    ) external payable returns (bool) {
        // require(msg.sender == _consumer, "Not Consumer");
        return doRelease(_tradeID, _serviceProvider, _consumer, _amount, _fee);
    }

    function consumerCancel(
        bytes16 _tradeID,
        address payable _serviceProvider,
        address payable _consumer,
        uint256 _amount,
        uint16 _fee
    ) external returns (bool) {
        // require(msg.sender == _consumer, "Not Consumer");    
        return
            doConsumerCancel(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );
    }

    function serviceProviderCancel(
        bytes16 _tradeID,
        address _serviceProvider,
        address payable _consumer,
        uint256 _amount,
        uint16 _fee
    ) external returns (bool) {
        // require(msg.sender == _serviceProvider, "Not Service provider");
        return
            doServiceProviderCancel(
                _tradeID,
                _serviceProvider,
                _consumer,
                _amount,
                _fee
            );
    }
    
    function subscriptionPayment(
         bytes16 _planID,
        address _serviceProvider,
        address payable _consumer
    ) external returns (bool) {
        // require(msg.sender == _consumer, "Not Consumer");
        return
            doSubscriptionPayment(
                _planID,
                _serviceProvider,
                _consumer
            );
    }
    
     function cancelSubscription(
         bytes16 _planID,
        address _serviceProvider,
        address payable _consumer
    ) external returns (bool) {
        // require(msg.sender == _consumer, "Not Consumer");
        return
            doCancelSubscription(
                _planID,
                _serviceProvider,
                _consumer
            );
    }

    function transferMinusFees(
        address payable _to,
        uint256 _amount,
        uint16 _fee
    ) private {
        uint256 _totalFees = ((_amount * _fee) / 10000);
        totalFees = _totalFees;
        if (_amount - _totalFees > _amount) return; // Prevent underflow
        feesAvailableForWithdraw += _totalFees;
        // _to.transfer(_amount - _totalFees);
        transferAmount(
              _to,
              (_amount - _totalFees)
              );
    }

    function withdrawFees(address payable _to, uint256 _amount)
        external
        onlyOwner
    {
        // require(_amount <= feesAvailableForWithdraw); // Prevents underflow
        feesAvailableForWithdraw -= _amount;
        _to.transfer(_amount);
    }

    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}
