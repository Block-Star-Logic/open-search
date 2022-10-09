// SPDX-License-Identifier: APACHE 2.0

pragma solidity ^0.8.15;
/**
 * @dev IOpenSearch is about searching fields to identify addresses of interest.
 */

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol";

import "https://github.com/Block-Star-Logic/open-register/blob/85c0a12e23b69c71a0c256938f6084cfdf651c77/blockchain_ethereum/solidity/V1/interfaces/IOpenRegister.sol";

import "https://github.com/Block-Star-Logic/open-roles/blob/732f4f476d87bece7e53bd0873076771e90da7d5/blockchain_ethereum/solidity/v2/contracts/interfaces/IOpenRolesManaged.sol";

import "https://github.com/Block-Star-Logic/open-roles/blob/fc410fe170ac2d608ea53e3760c8691e3c5b550e/blockchain_ethereum/solidity/v2/contracts/interfaces/IOpenRoles.sol";

import "https://github.com/Block-Star-Logic/open-roles/blob/732f4f476d87bece7e53bd0873076771e90da7d5/blockchain_ethereum/solidity/v2/contracts/core/OpenRolesSecureCore.sol";


import "../interfaces/IOpenSearch.sol";

contract OpenSearch is OpenRolesSecureCore, IOpenRolesManaged, IOpenVersion, IOpenSearch {

    string name                         = "RESERVED_OPEN_SEARCH_CORE"; 
    uint256 version                     = 15; 

    string registerCA                   = "RESERVED_OPEN_REGISTER_CORE";
    string roleManagerCA                = "RESERVED_OPEN_ROLES_CORE";
    
    IOpenRegister registry;
    
    using LOpenUtilities for string; 
    using LOpenUtilities for string[];
    using LOpenUtilities for address; 
    using LOpenUtilities for address[];
    using Strings        for uint256; 

    string openAdminRole  = "RESERVED_OPEN_ADMIN_ROLE";
    string dappCoreRole   = "DAPP_CORE_ROLE"; 
    string barredUserRole = "BARRED_USER_ROLE";

    string [] roleNames = [dappCoreRole, barredUserRole, openAdminRole]; 

    string textFieldType    = "TEXT_FIELD_TYPE";
    string numericFieldType = "NUMERIC_FIELD_TYPE";

    
    mapping(string=>bool) hasDefaultFunctionsByRole;
    mapping(string=>string[]) defaultFunctionsByRole;

    // field key 
    string [] searchFields; 
    mapping(string=>bool) knownField;     
    mapping(string=>bool) hasTypeByField; 
    mapping(string=>string) fieldTypeByField; 
    
        // text values
    mapping(string=>string[]) valuesBySearchField;
    mapping(string=>mapping(string=>address[])) addressesByValueByField;

        // numeric values
    mapping(string=>uint256[]) numericValuesByField; 
    mapping(string=>mapping(uint256=>bool)) hasValueByNumericValueByField;
    mapping(string=>mapping(uint256=>address[])) addressesByNumericValueByField;
    mapping(string=>mapping(uint256=>mapping(address=>bool))) hasAddressByNumericValueByField; 

    // address key
    mapping(address=>bool) hasAddress; 
    mapping(address=>mapping(string=>bool)) hasFieldByAddress; 
    mapping(address=>string[]) fieldsByAddress;
    mapping(address=>string[]) valuesByAddress; 
    mapping(address=>mapping(string=>string[])) valuesByFieldByAddress; 
    mapping(address=>mapping(string=>uint256[])) numericValuesByFieldByAddress;     

    // value key 
    mapping(string=>bool) isKnownValue; 
    mapping(string=>address[]) addressesByValue;     
    

    constructor(address _registryAddress, string memory _dappName) OpenRolesSecureCore(_dappName) {
        registry = IOpenRegister(_registryAddress);
        address openRoles_ = registry.getAddress(roleManagerCA);
        setRoleManager(openRoles_);
        addConfigurationItem(_registryAddress);
        addConfigurationItem(openRoles_);
        initDefaulFunctionsForRole();
    }

    function getName() view external  returns (string memory) {
        return name; 
    }

    function getVersion() view external returns (uint256){
        return version; 
    }

    function getDefaultRoles() override view external returns (string [] memory _roles){    
        return  roleNames; 
    }

    function hasDefaultFunctions(string memory _role) override view external returns(bool _hasFunctions){
        return hasDefaultFunctionsByRole[_role];
    }

    function getDefaultFunctions(string memory _role) override view external returns (string [] memory _functions){
        return defaultFunctionsByRole[_role];
    }

    function getAvailableSearchFields() view external returns (string [] memory _searchFields){
        return searchFields; 
    }

    function getSearchTerms(string memory _searchField) view external returns (string [] memory _searchTerms) {
        return valuesBySearchField[_searchField];
    }

    function searchField(string memory _value, string memory _field, uint256 _resultLimit) view external returns(address[] memory _results){
        require(isSecureBarring(barredUserRole, "searchField"), " user barred - text ");
        _results = addressesByValueByField[_field][_value];
        if(_results.length > _resultLimit) {
            address [] memory z = new address[](_resultLimit);
            for(uint256 x = 0; x < _resultLimit; x++){
                z[x] = _results[x];
            }
            return z; 
        }
        return _results; 
    }

    function searchField(uint256 _value, string memory _comparator, string memory _field, uint256 _resultLimit) view external returns (address[] memory _results){
        require(isSecureBarring(barredUserRole, "searchField"), " user barred - numeric ");
        _results = new address[](0);
        uint256 [] memory values_ = numericValuesByField[_field];
        for(uint256 x = 0; x < values_.length; x++){
            uint256 value_ = values_[x];
            if(_comparator.isEqual("GREATER_THAN")){
                if(_value < value_){
                    address [] memory addresses_ = addressesByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_comparator.isEqual("LESS_THAN")){
                if(_value > value_){
                    address [] memory addresses_ = addressesByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_comparator.isEqual("EQUAL_TO")){
                if(_value == value_){
                    address [] memory addresses_ = addressesByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_results.length >= _resultLimit) {
                break; 
            }
        }
        return _results; 
    }

    function generalSearch(string memory _value) view external returns(address [] memory _results) {
        if(isKnownValue[_value]) {
            return addressesByValue[_value];
        }
        return new address[](0);
    }

    function addGeneralSearchTermsForAddress(address _address, string [] memory _values) external returns (uint256 _termsAddedCount) {
        require(isSecure(dappCoreRole, "addGeneralSearchTermsForAddress"),"admin only");
        _termsAddedCount = addGeneralSearchTermsForAddressInternal(_address, _values);
        hasAddress[_address] = true; 
        return _termsAddedCount;
    }

    function addSearchableAddress(address _address, string memory _field, string[] memory _values) external returns (bool _added){
        require(isSecure(dappCoreRole, "addSearchableAddress"),"admin only");
        if(hasTypeByField[_field]){
            string memory fieldType = fieldTypeByField[_field];
            require(fieldType.isEqual(textFieldType), "Field <-> Type mis-match.");
        }
        else { 
            fieldTypeByField[_field] = textFieldType; 
            hasTypeByField[_field] = true; 
        }

        if(!knownField[_field]) {
            searchFields.push(_field);
            knownField[_field] = true;
        }
                
        if(!hasFieldByAddress[_address][_field]){
            fieldsByAddress[_address].push(_field);
            hasFieldByAddress[_address][_field] = true; 
        }
        
        valuesBySearchField[_field] = valuesBySearchField[_field].append(_values);

        // clean up only           
        valuesByFieldByAddress[_address][_field] = _values;

        for(uint256 x = 0; x < _values.length; x++){
            string memory value_  = _values[x];          
            addressesByValueByField[_field][value_].push(_address);                          
        }        

        addGeneralSearchTermsForAddressInternal(_address, _values);
        hasAddress[_address] = true; 
        return true; 
    }


    function addSearchableAddress(address _address, string memory _field, uint256 [] memory _values) external returns (bool _added){
        require(isSecure(dappCoreRole, "addSearchableAddress"),"admin only");
        if(!knownField[_field]) {
            searchFields.push(_field);
            knownField[_field] = true;
        }
        
        if(hasTypeByField[_field]){
            string memory fieldType = fieldTypeByField[_field];
            require(fieldType.isEqual(numericFieldType), "Field <-> Type mis-match.");
        }
        else { 
            fieldTypeByField[_field] = numericFieldType; 
             hasTypeByField[_field] = true; 
        }

        if(!hasFieldByAddress[_address][_field]){
            fieldsByAddress[_address].push(_field);
            hasFieldByAddress[_address][_field] = true; 
        }
        
        string [] memory _strValues = toString(_values); 
        valuesBySearchField[_field] = valuesBySearchField[_field].append(_strValues);

        // clean up only
        numericValuesByFieldByAddress[_address][_field] = _values; 
        for(uint256 x = 0; x < _values.length; x++){
            uint256 value_  = _values[x];
            
            if(!hasValueByNumericValueByField[_field][value_]){
                numericValuesByField[_field].push(value_);
                hasValueByNumericValueByField[_field][value_] = true; 
            }

            if(!hasAddressByNumericValueByField[_field][value_][_address]){            
                addressesByNumericValueByField[_field][value_].push(_address);
                hasAddressByNumericValueByField[_field][value_][_address] = true; 
            }
        }   
        addGeneralSearchTermsForAddressInternal(_address, _strValues);
        hasAddress[_address] = true; 
        return true; 
    }

    
    
    function removeSearchableAddress(address _address) external returns (bool _removed){
        require(isSecure(dappCoreRole, "removeSearchableAddress"),"admin only");
        if(!hasAddress[_address]){
            return false; 
        }

        string [] memory fields_ = fieldsByAddress[_address];        
        for(uint256 x = 0; x < fields_.length; x++){
            string memory field_ = fields_[x];
            string memory fieldType_ = fieldTypeByField[field_]; 
            if(fieldType_.isEqual(textFieldType)){
                removeTextSearchableFieldByAddress(_address, field_);
            }

            if(fieldType_.isEqual(numericFieldType)){
                removeNumericSearchableFieldByAddress(_address, field_);
            }
        }
    
        delete fieldsByAddress[_address];
        removeAddressFromGeneralSearchTerms(_address);
        return true;  
    }

    function notifyChangeOfAddress() external returns (bool _recieved){
        require(isSecure(openAdminRole, "notifyChangeOfAddress")," admin only ");    
        registry                = IOpenRegister(registry.getAddress(registerCA)); // make sure this is NOT a zero address               
        roleManager             = IOpenRoles(registry.getAddress(roleManagerCA));    
        addConfigurationItem(address(registry));   
        addConfigurationItem(address(roleManager));         
        
        return true; 
    }
    
    //================================= INTERNAL ======================================================

    function toString(uint256 [] memory n_)  pure internal returns (string [] memory _str){
        _str = new string[](n_.length);
        for(uint256 x = 0; x < n_.length; x++) {
            _str[x] = n_[x].toString(); 
        }
        return _str; 
    }

    function addGeneralSearchTermsForAddressInternal(address _address, string [] memory _values) internal returns (uint256 _termsAddedCount) {
        for(uint256 x = 0; x < _values.length; x++){
            string memory value_ = _values[x];
            isKnownValue[value_] = true; 
            addressesByValue[value_].push(_address);     
            valuesByAddress[_address].push(value_); 
        }
        return _termsAddedCount;
    }

    function removeTextSearchableFieldByAddress(address _address, string memory _field) internal returns(bool _removed) {                           
        string [] memory values_ = valuesByFieldByAddress[_address][_field];
        for( uint256 y = 0; y < values_.length; y++){
            string memory value_ = values_[y];
            address[] memory addresses_ = addressesByValueByField[_field][value_];
            addressesByValueByField[_field][value_] = _address.remove(addresses_);        
            string [] memory fields_ = fieldsByAddress[_address];
            fieldsByAddress[_address] = _field.remove(fields_);
        }
        removeAddressFromGeneralSearchTerms(_address);
        delete valuesByFieldByAddress[_address][_field];
        delete hasFieldByAddress[_address][_field]; 
        return true; 
    }

    function removeAddressFromGeneralSearchTerms(address _address) internal returns (uint256 _removeCount) {
        string [] memory values_ = valuesByAddress[_address];
        for(uint256 x = 0; x < values_.length; x++) {
            string memory value_ = values_[x];
            addressesByValue[value_] = _address.remove(addressesByValue[value_]);
            _removeCount++;
        }
        delete valuesByAddress[_address];
        return _removeCount; 
    }

    function removeNumericSearchableFieldByAddress(address _address, string memory _field) internal returns (bool _removed){
        uint256 [] memory values_ = numericValuesByFieldByAddress[_address][_field];
        for(uint256 x = 0; x < values_.length; x++){
            uint256 value_ = values_[x];            
            address [] memory v_ = addressesByNumericValueByField[_field][value_];            
            
            addressesByNumericValueByField[_field][value_] = _address.remove(v_);
            
            delete hasAddressByNumericValueByField[_field][value_][_address];
        }
        removeAddressFromGeneralSearchTerms(_address);
        string [] memory fields_ = fieldsByAddress[_address];
        fieldsByAddress[_address] = _field.remove(fields_);

        delete numericValuesByFieldByAddress[_address][_field];
        delete hasFieldByAddress[_address][_field]; 
        
        return true; 
    }

    function initDefaulFunctionsForRole()  internal returns (bool _initiated){
        hasDefaultFunctionsByRole[dappCoreRole] = true; 
        defaultFunctionsByRole[dappCoreRole].push("addSearchableAddress");
        defaultFunctionsByRole[dappCoreRole].push("removeSearchableAddress");
        defaultFunctionsByRole[dappCoreRole].push("addGeneralSearchTermsForAddress");
        
        hasDefaultFunctionsByRole[barredUserRole] = true;
        defaultFunctionsByRole[barredUserRole].push("searchField");
        
        hasDefaultFunctionsByRole[openAdminRole] = true;
        defaultFunctionsByRole[openAdminRole].push("notifyChangeOfAddress");
        return true; 
    }


}