// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./Component.sol";
import "@gif-interface/contracts/IOracle.sol";
import "@gif-interface/contracts/IOracleService.sol";

abstract contract OracleNew is
    IOracle, 
    Component 
{    
    event LogOracleCreated (address oracleAddress);
    event LogOracleProposed (uint256 id);
    event LogOracleApproved (uint256 id);
    event LogOracleDeclined (uint256 id);

    IOracleService private _oracleService;

    modifier onlyQuery {
        require(
             _msgSender() == _getContractAddress("Query"),
            "ERROR:ORA-001:ACCESS_DENIED"
        );
        _;
    }

    constructor(
        bytes32 name,
        address registry
    )
        Component(name, ORACLE_TYPE, registry)
    {
        _oracleService = IOracleService(_getContractAddress("OracleService"));
        emit LogOracleCreated(address(this));
    }

    // default callback function implementations
    function _afterApprove() internal override { 
        uint256 id = getId();
        // TODO figure out what the ... is wrong here
        // plugging id into the event let spin brownie console
        // with history[-1].info() ...
        // plugging in a fixed value eg 999 works fine????
        emit LogOracleApproved(999); 
    }

    function _afterPropose() internal override { emit LogOracleProposed(getId()); }
    function _afterDecline() internal override { emit LogOracleDeclined(getId()); }

    function request(uint256 requestId, bytes calldata requestData) external override onlyQuery {
        bytes memory responseData = _calculateResponseData(requestData);
        _oracleService.respond(requestId, responseData);
    }

    // this is the function that makes the call to the actual oracle
    // decodes input data
    // makes oracle call
    // link to oracle response
    // encodes oracle data and forwards it to product
    function _calculateResponseData(bytes calldata requestData) internal virtual returns (bytes memory responseData);
}
