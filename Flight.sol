// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

/// @author GreatLearningGroup3
/// @title Flight contract holding flight details
contract Flight {

    enum FlightState {ON_TIME, CANCELLED, DELAYED, DEPARTED}
    enum SeatCategory {ECONOMY, BUSINESS, PREMIUM}

    struct FlightData {
        string flightNumber;
        uint256 flightTime;
        uint256 departureTime;
        string from;
        string to;
        FlightState state;
		uint ethAmount;
    }

    mapping(string => FlightData) private flightsMap;

    FlightData flightData;

	/// Populates flights for the airlines
	/// @dev store flight data to flightsMap
    function populateFlights() public {
        flightsMap['EA007'] = FlightData("EA007", 1651833000, 0, "LON", "HYD", FlightState.ON_TIME, 10);
        flightsMap['EA001'] = FlightData("EA001", 1652783400, 0, "DXB", "HYD", FlightState.CANCELLED, 10);
        flightsMap['EA002'] = FlightData("EA002", 1651318200, 0, "HYD", "LON", FlightState.DELAYED, 10);
    }

	/// Get flight data for given airlines and flightNumber
	/// @param _flightNumber Flight whose data is to be lookedup for
	/// @dev Method does not perform parameter validation and caller of this method needs to validate the same
    function getFlightData(string memory _flightNumber) public view returns(FlightData memory){
        return flightsMap[_flightNumber];
    }

	/// Sets the flight state
	/// @param _flightNumber Flight whose state is to be set
	/// @param _state Flight state to set
    /// @param _delayInHours hours of delay of the flight
	/// @dev Method does not perform parameter validation and caller of this method needs to validate the same
    function setFlightState(string memory _flightNumber, Flight.FlightState _state, uint _delayInHours) public{
       flightsMap[_flightNumber].state = _state;
       
       if(FlightState.DELAYED == _state){
           flightsMap[_flightNumber].departureTime = flightsMap[_flightNumber].flightTime + _delayInHours*60*60;
       }else{
           flightsMap[_flightNumber].departureTime = flightsMap[_flightNumber].flightTime;
       }
    }
}
