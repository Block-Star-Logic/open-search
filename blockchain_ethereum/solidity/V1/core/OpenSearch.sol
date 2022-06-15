// SPDX-License-Identifier: APACHE 2.0

pragma solidity ^0.8.14;
/**
 * @dev IOpenSearch is about searching fields to identify addresses of interest.
 */
import "https://github.com/Block-Star-Logic/open-register/blob/85c0a12e23b69c71a0c256938f6084cfdf651c77/blockchain_ethereum/solidity/V1/interfaces/IOpenRegister.sol";
import "https://github.com/Block-Star-Logic/open-roles/blob/732f4f476d87bece7e53bd0873076771e90da7d5/blockchain_ethereum/solidity/v2/contracts/interfaces/IOpenRolesManaged.sol";
import "https://github.com/Block-Star-Logic/open-roles/blob/fc410fe170ac2d608ea53e3760c8691e3c5b550e/blockchain_ethereum/solidity/v2/contracts/interfaces/IOpenRoles.sol";
import "https://github.com/Block-Star-Logic/open-roles/blob/732f4f476d87bece7e53bd0873076771e90da7d5/blockchain_ethereum/solidity/v2/contracts/core/OpenRolesSecureCore.sol";

import "../interfaces/IOpenSearch.sol";

contract OpenSearch is OpenRolesSecureCore, IOpenRolesManaged, IOpenVersion, IOpenSearch {

    string name                         = "RESERVED_OPEN_SEARCH_CORE"; 
    uint256 version                     = 5; 

    string registerCA                   = "RESERVED_OPEN_REGISTER_CORE";
    string roleManagerCA                = "RESERVED_OPEN_ROLES_CORE";
    
    IOpenRegister registry;
    
    using LOpenUtilities for string; 
    using LOpenUtilities for address; 
    using LOpenUtilities for address[];

    string openAdminRole  = "RESERVED_OPEN_ADMIN_ROLE";
    string dappCoreRole   = "DAPP_CORE_ROLE"; 
    string barredUserRole = "BARRED_USER_ROLE";

    string [] roleNames = [dappCoreRole, barredUserRole, openAdminRole]; 

    string textFieldType    = "TEXT_FIELD_TYPE";
    string numericFieldType = "NUMERIC_FIELD_TYPE";

    
    mapping(string=>bool) hasDefaultFunctionsByRole;
    mapping(string=>string[]) defaultFunctionsByRole;

    mapping(string=>bool) knownField; 
    string [] searchFields; 
    mapping(string=>string[]) searchTermsBySearchField;

    mapping(string=>mapping(string=>address[])) addressListByTermByField;

    mapping(string=>uint256[]) numericValuesByField; 
    mapping(string=>mapping(uint256=>address[])) addressListByNumericValueByField;

    mapping(address=>string[]) fieldByAddress;

    mapping(address=>mapping(string=>string[])) valuesByFieldByAddress; 
    mapping(address=>mapping(string=>uint256[])) numericValuesByFieldByAddress; 

    mapping(string=>bool) hasTypeByField; 
    mapping(address=>mapping(string=>bool)) hasFieldByAddress; 
    mapping(string=>mapping(uint256=>bool)) hasValueByField;
    mapping(string=>mapping(uint256=>mapping(address=>bool))) hasAddressByNumericValueByField; 
    mapping(string=>string) fieldTypeByField; 

    mapping(string=>bool) isKnownByTerm; 
    mapping(string=>address[]) addressByKnownTerms;     
    mapping(address=>string[]) knownTermsByAddress; 

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
        return searchTermsBySearchField[_searchField];
    }

    function searchField(string memory _term, string memory _field, uint256 _resultLimit) view external returns(address[] memory _results){
        require(isSecureBarring(barredUserRole, "searchField"), " user barred - text ");
        _results = addressListByTermByField[_field][_term];
        if(_results.length > _resultLimit) {
            //_results.trim(_resultLimit);
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
                    address [] memory addresses_ = addressListByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_comparator.isEqual("LESS_THAN")){
                if(_value > value_){
                    address [] memory addresses_ = addressListByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_comparator.isEqual("EQUAL_TO")){
                if(_value == value_){
                    address [] memory addresses_ = addressListByNumericValueByField[_field][value_];
                    _results = _results.append(addresses_);
                }
            }

            if(_results.length >= _resultLimit) {
                break; 
            }
        }
        return _results; 
    }

    function generalSearch(string memory _term) view external returns(address [] memory _results) {
        if(isKnownByTerm[_term]) {
            return addressByKnownTerms[_term];
        }
        return new address[](0);
    }

    function addGeneralSearchTermsForAddress(address _address, string [] memory _terms) external returns (uint256 _termsAddedCount) {
        require(isSecure(dappCoreRole, "addGeneralSearchTermsForAddress"),"admin only");
        return addGeneralSearchTermsForAddressInternal(_address, _terms);
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
        searchTermsBySearchField[_field] = _values;
        
        fieldByAddress[_address].push(_field);
        for(uint256 x = 0; x < _values.length; x++){
            string memory value_  = _values[x];          
            addressListByTermByField[_field][value_].push(_address); 
            // clean up            
            valuesByFieldByAddress[_address][_field] = _values; 
        }
        fieldTypeByField[_field] = textFieldType; 
    
        addGeneralSearchTermsForAddressInternal(_address, _values);
        return true; 
    }


    function addSearchableAddress(address _address, string memory _field, uint256 [] memory _values) external returns (bool _added){
        require(isSecure(dappCoreRole, "addSearchableAddress"),"admin only");
        if(hasTypeByField[_field]){
            string memory fieldType = fieldTypeByField[_field];
            require(fieldType.isEqual(numericFieldType), "Field <-> Type mis-match.");
        }
        else { 
            fieldTypeByField[_field] = numericFieldType; 
             hasTypeByField[_field] = true; 
        }
        
        if(!hasFieldByAddress[_address][_field]){
            fieldByAddress[_address].push(_field);
            hasFieldByAddress[_address][_field] = true; 
        }

        for(uint256 x = 0; x < _values.length; x++){
            uint256 value_  = _values[x];
            
            if(!hasValueByField[_field][value_]){
                numericValuesByField[_field].push(value_);
                hasValueByField[_field][value_] = true; 
            }

            if(!hasAddressByNumericValueByField[_field][value_][_address]){            
                addressListByNumericValueByField[_field][value_].push(_address);
                hasAddressByNumericValueByField[_field][value_][_address] = true; 
            }
        }        
        return true; 
    }

    function removeSearchableAddress(address _address) external returns (bool _removed){
        require(isSecure(dappCoreRole, "removeSearchableAddress"),"admin only");
        string [] memory fields_ = fieldByAddress[_address];
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
        delete fieldByAddress[_address];
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

    function addGeneralSearchTermsForAddressInternal(address _address, string [] memory _terms) internal returns (uint256 _termsAddedCount) {
        for(uint256 x = 0; x < _terms.length; x++){
            string memory term_ = _terms[x];
            isKnownByTerm[term_] = true; 
            addressByKnownTerms[term_].push(_address);     
            knownTermsByAddress[_address].push(term_); 
        }
        return _termsAddedCount;
    }

    function removeTextSearchableFieldByAddress(address _address, string memory _field) internal returns(bool _removed) {           
        string [] memory values_ = valuesByFieldByAddress[_address][_field];
        for( uint256 y = 0; y < values_.length; y++){
            string memory value_ = values_[y];

            address[] memory addresses_ = addressListByTermByField[_field][value_];
            addressListByTermByField[_field][value_] = _address.remove(addresses_);        
        }
        delete valuesByFieldByAddress[_address][_field];
        delete hasFieldByAddress[_address][_field]; 
        return true; 
    }

    function removeAddressFromGeneralSearchTerms(address _address) internal returns (uint256 _removeCount) {
        string [] memory terms_ = knownTermsByAddress[_address];
        for(uint256 x = 0; x < terms_.length; x++) {
            string memory term_ = terms_[x];
            addressByKnownTerms[term_] = _address.remove(addressByKnownTerms[term_]);
            _removeCount++;
        }
        delete knownTermsByAddress[_address];
        return _removeCount; 
    }

    function removeNumericSearchableFieldByAddress(address _address, string memory _field) internal returns (bool _removed){
        uint256 [] memory values_ = numericValuesByFieldByAddress[_address][_field];
        for(uint256 x = 0; x < values_.length; x++){
            uint256 value_ = values_[x];
            
            addressListByNumericValueByField[_field][value_] = _address.remove( addressListByNumericValueByField[_field][value_]);
            delete hasAddressByNumericValueByField[_field][value_][_address];
        }
        delete numericValuesByFieldByAddress[_address][_field];
        delete hasFieldByAddress[_address][_field]; 
        return true; 
    }

    function initDefaulFunctionsForRole()  internal returns (bool _initiated){
        hasDefaultFunctionsByRole[dappCoreRole] = true; 
        defaultFunctionsByRole[dappCoreRole].push("addSearchableAddress");
        defaultFunctionsByRole[dappCoreRole].push("removeSearchableAddress");
        
        hasDefaultFunctionsByRole[barredUserRole] = true;
        defaultFunctionsByRole[barredUserRole].push("searchField");
        
        hasDefaultFunctionsByRole[openAdminRole] = true;
        defaultFunctionsByRole[openAdminRole].push("notifyChangeOfAddress");
        return true; 
    }


}