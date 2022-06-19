// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../shared/WithRegistry.sol";
import "../shared/Delegator.sol";
import "../modules/ILicense.sol";
// import "../shared/CoreController.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ProductService is 
    WithRegistry, 
    Delegator,
    // CoreController
    Context
 {
    event LogPsDummy1 (
        address licenceAddress
    );

    event LogPsDummy2 (
        uint256 id,
        bool authorized,
        address policyFlowAddress
    );

    bytes32 public constant NAME = "ProductService";

    // solhint-disable-next-line no-empty-blocks
    constructor(address _registry) WithRegistry(_registry) {}

    fallback() external {

        emit LogPsDummy1(address(_license()));

        (uint256 id, bool authorized, address policyFlow) = _license().authorize(_msgSender());

        emit LogPsDummy2(id, authorized, policyFlow);

        require(authorized, "ERROR:PRS-001:NOT_AUTHORIZED");
        require(policyFlow != address(0),"ERROR:PRS-002:POLICY_FLOW_NOT_RESOLVED");

        _delegate(policyFlow);
        // _delegate2(policyFlow);
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     * This function is a 1:1 copy of _delegate from 
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.6/contracts/proxy/Proxy.sol
     */
    function _delegate2(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // function _license() internal view returns (ILicense) {
    //     address licenseAddress = _getContractAddress("License");
    //     return ILicense(licenseAddress);
    // }
    
    function _license() internal view returns (ILicense) {
        return ILicense(registry.getContract("License"));
    }

}
