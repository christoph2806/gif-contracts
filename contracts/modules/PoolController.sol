// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./ComponentController.sol";
import "./PolicyController.sol";
import "../shared/CoreController.sol";

import "@gif-interface/contracts/modules/IPool.sol";
import "@gif-interface/contracts/components/IComponent.sol";
import "@gif-interface/contracts/components/IRiskpool.sol";


contract PoolController is
    IPool,
    CoreController
{
    mapping(uint256 => uint256) private _riskpoolIdForProductId;
    uint256 [] private _riskpools;

    ComponentController private _component;
    PolicyController private _policy;

    modifier onlyInstanceOperatorService() {
        require(
            _msgSender() == _getContractAddress("InstanceOperatorService"),
            "ERROR:POL-001:NOT_INSTANCE_OPERATOR"
        );
        _;
    }

    function _afterInitialize() internal override onlyInitializing {
        _component = ComponentController(_getContractAddress("Component"));
        _policy = PolicyController(_getContractAddress("Policy"));
    }

    function setRiskpoolForProduct(uint256 productId, uint256 riskpoolId) 
        external override
        onlyInstanceOperatorService
    {
        require(_component.exists(productId), "ERROR:POL-002:PRODUCT_DOES_NOT_EXIST");
        require(_component.exists(riskpoolId), "ERROR:POL-003:RISKPOOL_DOES_NOT_EXIST");
        
        if (_riskpoolIdForProductId[productId] == 0) {
            _riskpools.push(riskpoolId);
        }

        _riskpoolIdForProductId[productId] = riskpoolId;
    }

    function underwrite(bytes32 processId) 
        external override 
        onlyPolicyFlow("Pool")
        returns(bool success)
    {
        // check that application is in applied state
        IPolicy.Application memory application = _policy.getApplication(processId);
        require(
            application.state == IPolicy.ApplicationState.Applied,
            "ERROR:POL-004:INVALID_APPLICATION_STATE"
        );

        // determine riskpool responsible for application
        IPolicy.Metadata memory metadata = _policy.getMetadata(processId);
        IRiskpool riskpool = _getRiskpool(metadata);
        require(
            riskpool.getState() == ComponentState.Active, 
            "ERROR:POL-005:RISKPOOL_NOT_ACTIVE"
        );

        // ask riskpool to secure application
        success = riskpool.collateralizePolicy(processId);
        uint256 riskpoolId = riskpool.getId();
        uint256 sumInsured = application.sumInsuredAmount;

        if (success) {
            emit LogRiskpoolCollateralizationSucceeded(riskpoolId, processId, sumInsured);
        } else {
            emit LogRiskpoolCollateralizationFailed(riskpoolId, processId, sumInsured);
        }
    }


    function expire(bytes32 processId) 
        external override
        onlyPolicyFlow("Pool")
    {
        // check that policy is in aciive state
        IPolicy.Policy memory policy = _policy.getPolicy(processId);
        require(
            policy.state == IPolicy.PolicyState.Active,
            "ERROR:POL-007:INVALID_POLICY_STATE"
        );

        IPolicy.Metadata memory metadata = _policy.getMetadata(processId);
        IRiskpool riskpool = _getRiskpool(metadata);
        riskpool.expirePolicy(processId);
    }

    
    function riskpools() external view returns(uint256 idx) { return _riskpools.length; }
    function getRiskpoolId(uint256 idx) 
        external view 
        returns(uint256) 
    { 
        require(idx < _riskpools.length, "ERROR:POL-008:INDEX_TOO_LARGE");
        return _riskpools[idx]; 
    }


    function _getRiskpool(IPolicy.Metadata memory metadata) internal view returns (IRiskpool riskpool) {
        uint256 riskpoolId = _riskpoolIdForProductId[metadata.productId];
        require(riskpoolId > 0, "ERROR:POL-009:RISKPOOL_DOES_NOT_EXIST");

        IComponent cmp = _component.getComponent(riskpoolId);
        require(cmp.isRiskpool(), "ERROR:POL-010:COMPONENT_NOT_RISKPOOL");
        
        riskpool = IRiskpool(address(cmp));
    }
}
