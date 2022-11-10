/*
 Team 8: Dāda Bäce
 Adam Nash awn10@pitt.edu
 Jason Henriquez jth79@pitt.edu
 Ethan Dewit erd56@pitt.edu
 */

import javax.swing.*;
import java.io.IOException;
import java.sql.*;

public class Customer implements User {
	Connection conn = null;
	public void init(Connection conn) { this.conn = conn; }

	public void showMenu() {
		System.out.println("\n0: Quit\n1: Add customer\n" +
				"2: Show customer info, given customer name\n" +
				"3: Find price for flights between two cities\n" +
				"4: Find all routes between two cities\n" +
				"5: Find all routes between two cities of a given airline\n" +
				"6: Find all routes with available seats between two cities on a given date\n" +
				"7: Add reservation\n" +
				"8: Delete reservation\n" +
				"9: Show reservation info, given reservation number\n" +
				"10: Buy ticket from existing reservation\n" +
				"11: Find the top-k customers for each airline\n" +
				"12: Find the top-k traveled customers for each airline\n" +
				"13: Rank the airlines based on customer satisfaction\n");
	}

	public boolean selectOption(int choice) throws IOException, SQLException {
		String departureCity = "", arrivalCity = "", firstName = "", lastName = "";
		// if the departure and arrival city are needed
		if (choice > 2 && choice < 7) {
			System.out.println("Please enter the departure city:\n");
			departureCity = Menu.scan.nextLine();

			System.out.println("Please enter the arrival city:\n");
			arrivalCity = Menu.scan.nextLine();
		}

		// if the customer information is needed
		else if (choice == 1 || choice == 2 || choice == 7) {
			System.out.println("Please enter your first name:\n");
			firstName = Menu.scan.nextLine();

			System.out.println("Please enter your last name:\n");
			lastName = Menu.scan.nextLine();
		}

		if (choice == 0) {
			return false;
		} else if(choice == 1){
			addCustomer(firstName, lastName);
		} else if(choice == 2){
			displayCustomerInfo(firstName, lastName);
		} else if(choice == 3){
			getPriceBetweenCities(departureCity, arrivalCity);
		} else if(choice == 4){
			findAllRoutesBetween(departureCity, arrivalCity, -1);
		}else if(choice == 5){
			System.out.println("Please enter the airline you would like to use: ");
			String airline = Menu.scan.nextLine();

			PreparedStatement getAirID = conn.prepareStatement("select airline_id from airline where airline_name = ?");
			getAirID.setString(1, airline);
			try (ResultSet result = getAirID.executeQuery()) {

				if (result.next()) {
					int airlineID = result.getInt(1);

					findAllRoutesBetween(departureCity, arrivalCity, airlineID);
				}
			}
		}else if(choice == 6){
			System.out.println("Enter Your Departure Date\n" +
					"*Format the date as follows: MM-DD-YYYY");
			String flightDate = Menu.scan.nextLine();
			flightOnDate(departureCity, arrivalCity, flightDate);
		} else if(choice == 7){
			addReservation(firstName, lastName);
		} else if(choice == 8){
			removeReservation();
		} else if(choice == 9){
			showReservationInfo();
		} else if(choice == 10){
			buyTicket();
		} else if(choice == 11){
			topCustomers();
		} else if(choice == 12){
			topCustomersLegs();
		}else if(choice == 13){
			rankAirlineSatisfaction();
		}

		return true;
	}

	// Returns the customer tuple with matching name
	private ResultSet getCustomer(String firstName, String lastName) throws SQLException, IOException {
		try (PreparedStatement stmt = conn.prepareStatement("select * from customer where first_name = ? and last_name = ?;")) {
			stmt.setString(1, firstName);
			stmt.setString(2, lastName);

			return stmt.executeQuery();
		}
	}

	// Customer Task 1: add customer
	private void addCustomer(String firstName, String lastName) throws SQLException, IOException {
		ResultSet rs = getCustomer(firstName, lastName);

		if (rs.next()) {
			System.out.println("Error: a customer with this first and last name already exists.");
			rs.close();
			return;
		}

		try (PreparedStatement customerStatement = conn.prepareStatement("insert into customer (salutation, first_name, last_name, credit_card_num, "
				+ "credit_card_expire, street, city, state, phone, email, frequent_miles, cid) values (?, ?, ?, ?, TO_DATE(?, 'MM-DD-YYYY'), ?, ?, ?, ?, ?, ?, ?);"))
		{
			System.out.println("Please enter your salutation (Mr/Mrs/Ms/Mz):\n");
			customerStatement.setString(1, Menu.scan.nextLine());

			customerStatement.setString(2, firstName);
			customerStatement.setString(3, lastName);

			System.out.println("Please enter your credit card number:\n");
			customerStatement.setString(4, Menu.scan.nextLine());

			System.out.println("Please enter your credit card expiration date.\nFormat: MM-DD-YYYY. For example: '12/21/2019':\n");
			customerStatement.setString(5, Menu.scan.nextLine());

			System.out.println("We need your address. Please enter your street:\n");
			customerStatement.setString(6, Menu.scan.nextLine());

			System.out.println("Please enter your city:\n");
			customerStatement.setString(7, Menu.scan.nextLine());

			System.out.println("Please enter your state (e.g., PA, NY, VT):\n");
			customerStatement.setString(8, Menu.scan.nextLine());

			System.out.println("Please enter your phone number (e.g., '1234567890'):\n");
			customerStatement.setString(9, Menu.scan.nextLine());

			System.out.println("Please enter your email address:\n");
			customerStatement.setString(10, Menu.scan.nextLine());

			System.out.println("Please enter your frequent miles airline abbreviation (e.g., ALASKA, DELTA, UNITED):\n");
			customerStatement.setString(11, Menu.scan.nextLine());

			int cid = 1;
			// Generate new reservation_number
			try (Statement maxStmt = conn.createStatement()) {
				try (ResultSet result = maxStmt.executeQuery("select max(cid) from customer;")) {
					if (result.next()) {
						cid = result.getInt(1) + 1;
					}
				}
			}
			customerStatement.setInt(12, cid);

			if (customerStatement.executeUpdate() > 0) {
				System.out.println("Success! Your information has been added to the system.");
			} else {
				System.out.println("Error: your information was not able to be added to the system.");
			}
		} catch (Exception s) {
			System.out.println("Error: you have improperly inserted some of your information.");
		}
	}

	//Customer Task 2: display all information about a customer when given a name
	private void displayCustomerInfo(String firstName, String lastName) throws SQLException, IOException {
		try (ResultSet rs = getCustomer(firstName, lastName)) {
			if (!rs.isBeforeFirst()) {
				System.out.println("Error: no customer matching this first and last name found.");
				rs.close();
				return;
			}

			String salutation, credit_card_number, credit_card_expire, street, city, state, phone, email, freqMiles;
			rs.next();
			salutation = rs.getString("salutation");
			credit_card_number = rs.getString("credit_card_num");
			credit_card_expire = rs.getString("credit_card_expire");
			street = rs.getString("street");
			city = rs.getString("city");
			state = rs.getString("state");
			phone = rs.getString("phone");
			email = rs.getString("email");
			freqMiles = rs.getString("frequent_miles");


			System.out.println(salutation + " " + firstName + " " + lastName + " information:");
			System.out.println("\t Credit Card Number: " + credit_card_number);
			System.out.println("\t Credit Card Expire: " + credit_card_expire);
			System.out.println("\t Address: " + street + ", " + city + ", " + state);
			System.out.println("\t Phone: " + phone);
			System.out.println("\t email: " + email);
			System.out.println("\t Frequent Miles: " + freqMiles);
		}

		catch (Exception e) {
			System.out.println("Error: the system could not display your information properly.");
		}
	}

	//Customer Task 3: Find price between two cities

	private void getPriceBetweenCities(String cityA, String cityB) throws SQLException, IOException {
		//from cityA to cityB
		int highPrice, lowPrice, highPrice2, lowPrice2;
		try (PreparedStatement stmt = conn.prepareStatement("Select high_price, low_price from price where departure_city = ? and arrival_city = ?")) {
			stmt.setString(1, cityA);
			stmt.setString(2, cityB);

			try (ResultSet rs = stmt.executeQuery()) {
				if (!rs.next()) {
					System.out.println("Error: no matching price data for this route.");
					rs.close();
					return;
				}

				highPrice = rs.getInt("high_price");
				lowPrice = rs.getInt("low_price");
			}

			System.out.println("For a trip from " + cityA + " to " + cityB + ":");
			System.out.println("\tHigh Price = $" + highPrice);
			System.out.println("\tLow Price = $" + lowPrice);
		} catch (Exception e) {
			System.out.println("Error: our system could not find matching price data for this route.");
			return;
		}

		//from cityB to cityA
		try (PreparedStatement stmt2 = conn.prepareStatement("Select high_price, low_price from price where departure_city = ? and arrival_city = ?")) {
			stmt2.setString(1, cityB);
			stmt2.setString(2, cityA);
			try (ResultSet rs2 = stmt2.executeQuery()) {

				if (!rs2.next()) {
					System.out.println("Error: no matching price data for this route");
					rs2.close();
					return;
				}

				highPrice2 = rs2.getInt("high_price");
				lowPrice2 = rs2.getInt("low_price");
			}
		} catch (Exception e) {
			System.out.println("Our system could not find matching price data for this route.");
			return;
		}

		System.out.println("For a trip from " + cityB + " to " + cityA + ":");
		System.out.println("\tHigh Price = $" + highPrice);
		System.out.println("\tLow Price = $" + lowPrice);

		//Prices for a round-trip ticket between city A and city B?? how to know whether to use high or low price
		int roundHigh = highPrice + highPrice2;
		int roundLow = lowPrice + lowPrice2;
		System.out.println("High price for a round-trip from " + cityA + " to " + cityB + ": $" + roundHigh);
		System.out.println("Low price for a round-trip from " + cityB + " to " + cityA + ": $" + roundLow);
	}

	// Customer tasks 4 and 5: Find all routes between two cities
	// Finds based on airline if airlineID argument is not
	private void findAllRoutesBetween(String departureCity, String arrivalCity, int airlineID) throws SQLException, IOException {
		// select all direct routes between these cities
		String directRouteQuery, connectionQuery;
		if (airlineID != -1) {
			directRouteQuery = "select flight_number, departure_time, arrival_time "
					+ "from flight where departure_city = ? and arrival_city = ? and airline_id = ?;";

			connectionQuery = "select firstFlight.weekly_schedule, secondFlight.weekly_schedule, firstFlight.arrival_time, "
					+ "secondFlight.departure_time, firstFlight.flight_number, secondFlight.flight_number, firstFlight.departure_time, secondFlight.arrival_time, firstFlight.arrival_city "
					+ "from flight secondFlight join departureFrom(?) firstFlight "
					+ "on firstFlight.arrival_city = secondFlight.departure_city where secondFlight.arrival_city = ? and firstFlight.airline_id = ? and secondFlight.airline_id = ?;";
		} else {
			directRouteQuery = "select flight_number, departure_time, arrival_time "
					+ "from flight where departure_city = ? and arrival_city = ?;";

			connectionQuery = "select firstFlight.weekly_schedule, secondFlight.weekly_schedule, firstFlight.arrival_time, "
					+ "secondFlight.departure_time, firstFlight.flight_number, secondFlight.flight_number, firstFlight.departure_time, secondFlight.arrival_time, firstFlight.arrival_city "
					+ "from flight secondFlight join departureFrom(?) firstFlight "
					+ "on firstFlight.arrival_city = secondFlight.departure_city where secondFlight.arrival_city = ?;";
		}

		try (PreparedStatement directRouteStatement = conn.prepareStatement(directRouteQuery)) {
			directRouteStatement.setString(1, departureCity);
			directRouteStatement.setString(2, arrivalCity);

			if (airlineID != -1) {
				directRouteStatement.setInt(3, airlineID);
			}

			try (ResultSet directRoutes = directRouteStatement.executeQuery()) {

				while (directRoutes.next()) {
					int flightNumber = directRoutes.getInt("flight_number");
					String departureTime = directRoutes.getString("departure_time");
					String arrivalTime = directRoutes.getString("arrival_time");

					//System.out.println("Flight " + flightNumber + " departs " + departureCity + " at " + departureTime + " and arrives at " + arrivalTime);
					System.out.println("Flight Number: " + flightNumber + ". Departure City: " + departureCity +
							". Departure Time: " + departureTime + ". Arrival Time: " + arrivalTime);
				}
			}
		} catch (Exception e) {
			System.out.println("Error: Could not fetch information about direct routes.");
			return;
		}

		// select firstFlight arriving to connection and secondFlight departing from connection
		try (PreparedStatement connectionStatement = conn.prepareStatement(connectionQuery)) {
			connectionStatement.setString(1, departureCity);
			connectionStatement.setString(2, arrivalCity);

			if (airlineID != -1) {
				connectionStatement.setInt(3, airlineID);
				connectionStatement.setInt(4, airlineID);
			}

			try (ResultSet connectionRoutes = connectionStatement.executeQuery()) {
				while (connectionRoutes.next()) {
					String flightSchedule1 = connectionRoutes.getString(1);
					String flightSchedule2 = connectionRoutes.getString(2);

					// If the flight schedules do not have a single day of overlap, it is not a valid connection
					if (!scheduleOverlap(flightSchedule1, flightSchedule2)) {
						continue;
					}

					int arrivalTime1 = Integer.parseInt(connectionRoutes.getString(3));
					int departureTime2 = Integer.parseInt(connectionRoutes.getString(4));

					// If the second flight departs less than an hour after the first flight arrives, it is not a valid connection
					if (departureTime2 - arrivalTime1 >= 100) {
						int flightNumber1 = connectionRoutes.getInt(5);
						int flightNumber2 = connectionRoutes.getInt(6);
						String departureTime1 = connectionRoutes.getString(7);
						String arrivalTime2 = connectionRoutes.getString(8);
						String connectionCity = connectionRoutes.getString(9);


						//System.out.println("Flight " + flightNumber + " departs " + departureCity + " at " + departureTime1 + " and arrives at " + arrivalTime2);

						System.out.println("Flight #" + flightNumber1 + " departs from " + departureCity +
								" at " + departureTime1 + "\n\tand reaches its destination at " + arrivalTime1 +
								".\nFlight #" + flightNumber2 + " departs from " + connectionCity +
								" at " + departureTime2 + "\n\tand reaches its destination at " + arrivalTime2 + ".");
					}
				}
			}
		} catch (Exception e) {
			System.out.println("Could not fetch information about routes with one connection.");
		}
	}

	// Determines if two flight schedules have at least one day in which they are both active
	private boolean scheduleOverlap(String flightSchedule1, String flightSchedule2) {
		for (int i = 0; i < 7; ++i) {
			if (flightSchedule1.charAt(i) != '-' && flightSchedule2.charAt(i) != '-') {
				return true;
			}
		}

		return false;
	}

	//customer task 6: all routes of a given day
	/*assumptions: 	Flights that can be upgraded but are at full capacity will not be shown
					Flights that have connections need to have at least one day they are overlapping,
						Given this and the wording of the task 6 description we assume that they need to have departure
						dates on the same date
	 */
	public void flightOnDate(String departureCity, String arrivalCity, String flightDate) throws SQLException, IOException{
		String directRouteQuery, connectionQuery;
		directRouteQuery = "select flight_number, departure_time, arrival_time "
				+ "from flight where departure_city = ? and arrival_city = ? "
				+ "and getDayLetterFromSchedule(TO_DATE(?, 'MM-DD-YYYY'), flight_number) != '-' "
				+ "and isFull(flight_number, getCalculatedDepartureDate(to_date(?, 'MM-DD-YYYY'), flight_number)) = false;";

		connectionQuery = "select firstFlight.weekly_schedule, secondFlight.weekly_schedule, firstFlight.arrival_time, "
				+ "secondFlight.departure_time, firstFlight.flight_number, secondFlight.flight_number, firstFlight.departure_time, secondFlight.arrival_time, firstFlight.arrival_city "
				+ "from flight secondFlight join departureFrom(?) firstFlight "
				+ "on firstFlight.arrival_city = secondFlight.departure_city where secondFlight.arrival_city = ? "
				+ "and getDayLetterFromSchedule(TO_DATE(?, 'MM-DD-YYYY'), firstFlight.flight_number) != '-' "
				+ "and isFull(firstFlight.flight_number, getCalculatedDepartureDate(to_date(?, 'MM-DD-YYYY'), firstFlight.flight_number)) = false "
				+ "and isFull(secondFlight.flight_number, getCalculatedDepartureDate(to_date(?, 'MM-DD-YYYY'), secondFlight.flight_number)) = false;";

		PreparedStatement directRouteStatement = conn.prepareStatement(directRouteQuery);
		directRouteStatement.setString(1, departureCity);
		directRouteStatement.setString(2, arrivalCity);
		directRouteStatement.setString(3, flightDate);
		directRouteStatement.setString(4, flightDate);

		ResultSet directRoutes = directRouteStatement.executeQuery();
		directRouteStatement.close();

		while (directRoutes.next()) {
			int flightNumber = directRoutes.getInt("flight_number");
			String departureTime = directRoutes.getString("departure_time");
			String arrivalTime = directRoutes.getString("arrival_time");

			//System.out.println("Flight " + flightNumber + " departs " + departureCity + " at " + departureTime + " and arrives at " + arrivalTime);
			System.out.println("Flight Number: " + flightNumber + ". Departure City: " + departureCity +
					". Departure Time: " + departureTime + ". Arrival Time: " + arrivalTime);
		}

		directRoutes.close();

		PreparedStatement connectionStatement = conn.prepareStatement(connectionQuery);
		connectionStatement.setString(1, departureCity);
		connectionStatement.setString(2, arrivalCity);
		connectionStatement.setString(3, flightDate);
		connectionStatement.setString(4, flightDate);
		connectionStatement.setString(5, flightDate);


		ResultSet connectionRoutes = connectionStatement.executeQuery();
		connectionStatement.close();

		while (connectionRoutes.next()) {
			String flightSchedule1 = connectionRoutes.getString(1);
			String flightSchedule2 = connectionRoutes.getString(2);

			// If the flight schedules do not have a single day of overlap, it is not a valid connection
			if (!scheduleOverlap(flightSchedule1, flightSchedule2)) {
				continue;
			}

			int arrivalTime1 = Integer.parseInt(connectionRoutes.getString(3));
			int departureTime2 = Integer.parseInt(connectionRoutes.getString(4));

			// If the second flight departs less than an hour after the first flight arrives, it is not a valid connection
			if (departureTime2 - arrivalTime1 >= 100) {
				int flightNumber1 = connectionRoutes.getInt(5);
				int flightNumber2 = connectionRoutes.getInt(6);
				String departureTime1 = connectionRoutes.getString(7);
				String arrivalTime2 = connectionRoutes.getString(8);
				String connectionCity = connectionRoutes.getString(9);


				//System.out.println("Flight " + flightNumber + " departs " + departureCity + " at " + departureTime1 + " and arrives at " + arrivalTime2);

				System.out.println("Flight #" + flightNumber1 + " departs from " + departureCity +
						" at " + departureTime1 + "\n\tand reaches its destination at " + arrivalTime1 +
						".\nFlight #" + flightNumber2 + " departs from " + connectionCity +
						" at " + departureTime2 + "\n\tand reaches its destination at " + arrivalTime2 + ".");
			}
		}

		connectionRoutes.close();
	}


	// Customer Task 7: Add a reservation
	private void addReservation(String firstName, String lastName) throws SQLException, IOException {
		ResultSet foundCustomer = getCustomer(firstName, lastName);

		if (!foundCustomer.next()) {
			System.out.println("No customer matching this profile found.\n");
			foundCustomer.close();
			return;
		}

		int cid = foundCustomer.getInt("cid");
		String creditCardNumber = foundCustomer.getString("credit_card_num");

		foundCustomer.close();

		int [] flightNumbers = new int[4];
		String [] timestamps = new String[4];

		int i;
		for (i = 0; i < 4; ++i) {
			System.out.println("For leg " + (i + 1) + " of your trip, please type your flight number:\n");
			if (i > 0) {
				System.out.println("Type '0' if you have no remaining flights for your reservation:\n");
			}

			flightNumbers[i] = Integer.parseInt(Menu.scan.nextLine());
			if (i > 0 && flightNumbers[i] == 0) {
				break;
			}

			System.out.println("Please type the date of this leg of your trip (e.g., '05/26/2020'):\n");
			timestamps[i] = Menu.scan.nextLine();
		}

		try {
			conn.setAutoCommit(false);

			int reservationNumber = 1;

			// Generate new reservation_number
			try (Statement stmt = conn.createStatement()) {
				ResultSet rs = stmt.executeQuery("select max(reservation_number) from reservation;");
				if (rs.next()) {
					reservationNumber = rs.getInt(1) + 1;
				} else {
					System.out.println("Our system is having some issues right now. Please call the Pitt Tours hotline.");
					rs.close();
					stmt.close();

				}
			}

			try (PreparedStatement insertStatement = conn.prepareStatement("insert into reservation values (?, ?, ?, ?, ?, ?);")) {
				insertStatement.setInt(1, reservationNumber);
				insertStatement.setInt(2, cid);
				insertStatement.setInt(3, 0);
				insertStatement.setString(4, creditCardNumber);
				insertStatement.setBoolean(6, false);

				try (Statement stmt = conn.createStatement()) {
					try (ResultSet current = stmt.executeQuery("select * from ourtimestamp;")) {
						if (current.next()) {
							insertStatement.setTimestamp(5, current.getTimestamp(1));
						}
					}
				}

				if (insertStatement.executeUpdate() == 0) {
					System.out.println("Error: could not create a valid reservation with the provided information.");
					insertStatement.close();
					throw new SQLException("Invalid reservation");
				}
			}

			try (CallableStatement cs = conn.prepareCall("CALL makeReservation(?, ?, ?::DATE, ?);")) {
				for (int leg = 0; leg < i; ++leg) {
					cs.setInt(1, reservationNumber);
					cs.setInt(2, flightNumbers[leg]);
					cs.setString(3, timestamps[leg]);
					cs.setInt(4, leg + 1);

					cs.execute();
				}
			}

			// Sets the proper cost of the reservation
			try (CallableStatement cs = conn.prepareCall("CALL setReservationCost(?);")) {
				cs.setInt(1, reservationNumber);
				cs.execute();
			}

			conn.commit();

			System.out.println("Reservation confirmed! Your reservation number is " + reservationNumber + ".");
		} catch (SQLException e) {
			System.out.println("Error: no seat available on one or more of your flights.\n");
			conn.rollback();
		}
	}


	//Customer Task 8: Remove a reservation
	private void removeReservation() throws SQLException{
		System.out.println("Please enter the Reservation ID number:\n");
		String input = Menu.scan.nextLine();
		int resNumb = Integer.parseInt(input);

		PreparedStatement remove1 = conn.prepareStatement("delete from reservation where reservation_number = ?");
		PreparedStatement remove2 = conn.prepareStatement("delete from reservation_detail where reservation_number = ?");

		remove1.setInt(1, resNumb);
		remove2.setInt(1, resNumb);


		//ACID
		try{
			conn.setAutoCommit(false);
			remove1.executeUpdate();
			remove2.executeUpdate();
			conn.commit();
		}catch(SQLException e1){
			try{
				conn.rollback();
				System.out.println("Error: could not remove reservation.");
			}catch(SQLException e2){
				System.out.println("Error: problem connecting to the server. Please contact the Pitt Tours hotline.");
			}
		} finally {
			remove1.close();
			remove2.close();
		}
	}

	//	Customer Task 9: get all the flights for the given reservation
	private void showReservationInfo() throws SQLException, IOException {
		System.out.println("Please enter your reservation number:\n");
		String input = Menu.scan.nextLine();
		int resNum = Integer.parseInt(input);

		//	Show reservation info, given reservation number
		try (PreparedStatement stmt = conn.prepareStatement("Select * from reservation_detail where reservation_number = ?")) {
			stmt.setInt(1, resNum);

			try (ResultSet rs = stmt.executeQuery()) {
				if (!rs.isBeforeFirst()) {
					System.out.println("Sorry, there are no reservations corresponding to " + resNum);
				}

				else{
					System.out.println("Flights associated with " + resNum + ":");
					while(rs.next()){
						int flightNum = rs.getInt("flight_number");
						String flightDate = rs.getDate("flight_date").toString();
						int leg = rs.getInt("leg");
						System.out.println("\tFlight Number: " + flightNum + ". " + "Date: " + flightDate + ". Leg " + leg);
					}
				}
			}
		} catch (Exception e) {
			System.out.println("Error: could not fetch the flight information for the given reservation.");
		}
	}

	// Customer Task 10: Buy ticket from existing reservation
	private void buyTicket() throws SQLException, IOException {
		PreparedStatement buyTicketStatement = conn.prepareStatement("update reservation set ticketed = true where reservation_number = ?;");

		System.out.println("Please supply your reservation number:\n");
		int reservationNumber = Integer.parseInt(Menu.scan.nextLine());
		buyTicketStatement.setInt(1, reservationNumber);

		if (buyTicketStatement.executeUpdate() != 0) {
			System.out.println("Your reservation is now, or aleady was, a purchased ticket.");
		} else {
			System.out.println("Error: ticket purchase unsuccessful. You may have provided an incorrect reservation number.");
		}
	}


	//Customer Task 11: Display top k customers per airline
	private void topCustomers() throws SQLException, IOException {
		System.out.println("Please provide as an integer how many top customers would you like to display:\n");
		String input = Menu.scan.nextLine();
		int topK = Integer.parseInt(input);

		PreparedStatement stmt = conn.prepareStatement(
				"select airline.airline_name, topPayers.name, rank() " +
						"over(partition by topPayers.airline_id order by topPayers.price desc) " +
						"from topPayers, airline " +
						"where airline.airline_id = topPayers.airline_id;");
		//stmt.setInt(1, topK);

		ResultSet rs = stmt.executeQuery();

		String name;
		String airline;
		int rank;

		while(rs.next()){
			name = rs.getString("name");
			airline = rs.getString("airline_name");
			rank = rs.getInt("rank");
			if(rank <= topK){ System.out.println(airline + " rank " + rank + " customer is: " + name); }
		}
		System.out.println();
		stmt.close();
	}

	//	Customer Task 12
	//	Find the top-k traveled customers for each airline
	//	Ask the user to supply k the number of top-k customers they desire to display.
	// 	The system should display, for each airline, the top-k customers with the highest number of legs with that airline.
	private void topCustomersLegs() throws SQLException {
		System.out.println("Please provide as an integer how many top customers would you like to display:\n");
		String input = Menu.scan.nextLine();
		int topK = Integer.parseInt(input);

		//returns cid, airline, and total times each customer flew on each airline
		try(PreparedStatement stmt = conn.prepareStatement(
				"select c.first_name, c.last_name, r.cid, a.airline_name, COUNT(*), RANK () OVER ( " +
						"ORDER BY COUNT(*) DESC) rank " +
						"from reservation r JOIN reservation_detail rd on r.reservation_number = rd.reservation_number " +
						"JOIN flight f on rd.flight_number = f.flight_number " +
						"JOIN airline a on a.airline_id = f.airline_id " +
						"JOIN customer c on c.cid = r.cid " +
						"group by r.cid, a.airline_name, c.first_name, c.last_name;", ResultSet.TYPE_SCROLL_SENSITIVE,
				ResultSet.CONCUR_UPDATABLE)){
			//stmt.setInt(1, topK);
			try(ResultSet rs = stmt.executeQuery()) {
				//gets set of all airlines
				try (PreparedStatement stmtGetAirlines = conn.prepareStatement("select airline_name from airline;")) {
					try (ResultSet airlineSet = stmtGetAirlines.executeQuery()) {

						while (airlineSet.next()) {
							String airlineTemp = airlineSet.getString("airline_name");
							System.out.println(airlineTemp + " top " + topK + " customers by number of flights:");
							//have inner loop that sorts thru max customer for airline from outer loop
							while (rs.next()) {
								//if airline matches current iteration & rank is equal to or lower than K, print customer info
								if (rs.getString("airline_name").equals(airlineTemp) && rs.getInt("rank") <= topK) {
									String c = rs.getString("first_name") + " " + rs.getString("last_name");
									int count = rs.getInt("count");
									System.out.println("\tName: " + c + ". Number of Flights: " + count);
								}
							}
							rs.first();
						}
					}
				}
			}
		}

	}

	// Customer Task 13: Rank the airlines based on customer satisfaction
	private void rankAirlineSatisfaction() throws IOException, SQLException {
		// Select a ranking of airlines by unique ticketed customer count
		try (Statement rankStatement = conn.createStatement()) {
			ResultSet rankedAirlines = rankStatement.executeQuery("select airline_id, airline_name, RANK () OVER ( "
					+ "ORDER BY ticketed_customers DESC )"
					+ " satisfaction_rank FROM ticketed_by_airline NATURAL JOIN airline;");

			int lastSatisfactionRank = -1;
			while (rankedAirlines.next()) {
				int airlineID = rankedAirlines.getInt(1);
				String airlineName = rankedAirlines.getString(2);
				int satisfactionRank = rankedAirlines.getInt(3);

				if (lastSatisfactionRank == satisfactionRank) {
					System.out.println("\t...as does " + airlineName + " (Airline #" + airlineID + ")");
				}

				else {
					System.out.println(airlineName + " (Airline #" + airlineID + ") holds satisfaction ranking " + satisfactionRank);
				}

				lastSatisfactionRank = satisfactionRank;
			}

			rankedAirlines.close();
		}
	}
}
