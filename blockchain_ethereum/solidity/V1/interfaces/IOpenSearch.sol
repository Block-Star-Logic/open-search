// SPDX-License-Identifier: APACHE 2.0

pragma solidity >=0.8.0 <0.9.0;
/**
 * @dev IOpenSearch is about searching fields to identify addresses of interest.
 */
interface IOpenSearch {

    function searchField(string memory _term, string memory _field, uint256 _resultLimit) view external returns(address[] memory _results);

    function searchField(uint256 _value, string memory _comparator, string memory _field, uint256 _resultLimit) view external returns (address[] memory _results);

    function generalSearch(string memory _term) view external returns (address [] memory _results);

    function addSearchableAddress(address _address, string memory _field, string[] memory _values) external returns (bool _added);

    function addSearchableAddress(address _address, string memory _field, uint256 [] memory _values) external returns (bool _added);
    
    function addGeneralSearchTermsForAddress(address _address, string [] memory _terms) external returns (uint256 _termsAddedCount);

    function removeSearchableAddress(address _address) external returns (bool _removed);

}