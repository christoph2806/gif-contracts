// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./IdSet.sol";

import "@gif-interface/contracts/modules/IBundle.sol";
import "@gif-interface/contracts/modules/IPolicy.sol";
import "@gif-interface/contracts/components/Component.sol";
import "@gif-interface/contracts/components/IRiskpool.sol";
import "@gif-interface/contracts/services/IInstanceService.sol";
import "@gif-interface/contracts/services/IRiskpoolService.sol";

// TODO consider to move bunlde per riskpool book keeping to bundle controller
abstract contract Riskpool is 
    IRiskpool, 
    IdSet,
    Component 
{
    // TODO move events to IRiskpool (gif-interface)
    event LogRiskpoolBundleCreated(uint256 bundleId, uint256 amount);
    event LogRiskpoolRequiredCollateral(bytes32 processId, uint256 sumInsured, uint256 collateral);
    event LogRiskpoolBundleMatchesPolicy(uint256 bundleId, bool isMatching);
    event LogRiskpoolCollateralLocked(bytes32 processId, uint256 collateralAmount, bool isSecured);
    
    // used for representation of collateralization
    // collateralization between 0 and 1 (1=100%) 
    // value might be larger when overcollateralization
    uint256 public constant COLLATERALIZATION_DECIMALS = 10000;
    string public constant DEFAULT_FILTER_DATA_STRUCTURE = "";

    IInstanceService internal _instanceService; 
    IRiskpoolService internal _riskpoolService;
    
    // keep track of bundles associated with this riskpool
    uint256 [] internal _bundleIds;

    address private _wallet;
    uint256 private _collateralization;
    uint256 private _capital;
    uint256 private _lockedCapital;
    uint256 private _balance;

    modifier onlyPool {
        require(
             _msgSender() == _getContractAddress("Pool"),
            "ERROR:RPL-001:ACCESS_DENIED"
        );
        _;
    }

    constructor(
        bytes32 name,
        uint256 collateralization,
        address wallet,
        address registry
    )
        Component(name, ComponentType.Riskpool, registry)
    { 
        require(collateralization != 0, "ERROR:RPL-002:COLLATERALIZATION_ZERO");
        _collateralization = collateralization;

        require(wallet != address(0), "ERROR:RPL-003:WALLET_ADDRESS_ZERO");
        _wallet = wallet;

        _instanceService = IInstanceService(_getContractAddress("InstanceService")); // TODO change to IInstanceService
        _riskpoolService = IRiskpoolService(_getContractAddress("RiskpoolService"));
    }

    // TODO decide on authz for bundle creation
    function createBundle(bytes calldata filter, uint256 initialAmount) 
        external override
        returns(uint256 bundleId)
    {
        address bundleOwner = _msgSender();
        bundleId = _riskpoolService.createBundle(bundleOwner, filter, initialAmount);
        _bundleIds.push(bundleId);

        IBundle.Bundle memory bundle = _instanceService.getBundle(bundleId);
        if (bundle.state == IBundle.BundleState.Active) {
            _addIdToSet(bundleId);
        }
        
        // update financials
        _capital += initialAmount;
        _balance += initialAmount;

        emit LogRiskpoolBundleCreated(bundleId, initialAmount);
    }


    function collateralizePolicy(bytes32 processId) 
        external override
        onlyPool
        returns(bool success) 
    {
        IPolicy.Application memory application = _instanceService.getApplication(processId);
        uint256 sumInsured = application.sumInsuredAmount;
        uint256 collateralAmount = calculateCollateral(application);
        emit LogRiskpoolRequiredCollateral(processId, sumInsured, collateralAmount);

        success = _lockCollateral(processId, collateralAmount);
        if (success) {
            _lockedCapital += collateralAmount;
        }

        emit LogRiskpoolCollateralLocked(processId, collateralAmount, success);
    }

    function expirePolicy(bytes32 processId) 
        external override
        onlyPool
    {
        uint256 collateralAmount = _freeCollateral(processId);
        require(
            collateralAmount <= _lockedCapital,
            "ERROR:RPL-005:FREED_COLLATERAL_TOO_BIG"
        );

        _lockedCapital -= collateralAmount;
    }

    function preparePayout(bytes32 processId, uint256 payoutId, uint256 amount) external override {
        revert("ERROR:RPL-991:SECURE_PAYOUT_NOT_IMPLEMENTED");
    }

    function executePayout(bytes32 processId, uint256 payoutId) external override {
        revert("ERROR:RPL-991:EXECUTE_PAYOUT_NOT_IMPLEMENTED");
    }

    function getCollateralizationDecimals() public pure override returns (uint256) {
        return COLLATERALIZATION_DECIMALS;
    }

    function getCollateralizationLevel() public view override returns (uint256) {
        return _collateralization;
    }

    function calculateCollateral(IPolicy.Application memory application) 
        public // override
        view 
        returns (uint256 collateralAmount) 
    {
        uint256 sumInsured = application.sumInsuredAmount;
        uint256 collateralization = getCollateralizationLevel();

        if (collateralization == COLLATERALIZATION_DECIMALS) {
            collateralAmount = sumInsured;
        } else {
            // https://ethereum.stackexchange.com/questions/91367/is-the-safemath-library-obsolete-in-solidity-0-8-0
            collateralAmount = (collateralization * sumInsured) / COLLATERALIZATION_DECIMALS;
        }
    }

    function bundles() public override view returns(uint256) {
        return _bundleIds.length;
    }

    function getBundle(uint256 idx) public override view returns(IBundle.Bundle memory) {
        require(idx < _bundleIds.length, "ERROR:RPL-006:BUNDLE_INDEX_TOO_LARGE");

        uint256 bundleIdx = _bundleIds[idx];
        return _instanceService.getBundle(bundleIdx);
    }

    function getFilterDataStructure() external override pure returns(string memory) {
        return DEFAULT_FILTER_DATA_STRUCTURE;
    }

    function getCapital() public view returns(uint256) {
        return _capital;
    }

    function getTotalValueLocked() public override view returns(uint256) {
        return _lockedCapital;
    }

    function getCapacity() public override view returns(uint256) {
        return _capital - _lockedCapital;
    }

    function getBalance() external override view returns(uint256) {
        return _balance;
    }

    // TODO move the two functions below to IRiskpool
    function bundleMatchesApplication(IBundle.Bundle memory bundle, IPolicy.Application memory application) public view virtual returns(bool isMatching);

    function _lockCollateral(bytes32 processId, uint256 collateralAmount) internal virtual returns(bool success);
    function _freeCollateral(bytes32 processId) internal virtual returns(uint256 collateralAmount);

}