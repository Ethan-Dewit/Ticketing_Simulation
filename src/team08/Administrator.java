/*
 Team 8: Dāda Bäce
 Adam Nash awn10@pitt.edu
 Jason Henriquez jth79@pitt.edu
 Ethan Dewit erd56@pitt.edu
 */

import java.io.*;
import java.sql.*;

public class Administrator implements User {
	private Connection conn = null;

	public void init(Connection conn){ this.conn = conn; }

	public void showMenu(){
		System.out.println("\n0: Quit\n1: Erase the database\n" +
				"2: Load airline information\n" +
				"3: Load schedule information\n" +
				"4: Load pricing information\n" +
				"5: Load plane information\n" +
				"6: Generate passenger manifest for specific flight on given day\n" +
				"7: Update the current timestamp\n");
	}

	public boolean selectOption(int choice) throws IOException, SQLException {
		if (choice == 0) {
			return false;
		}

		else if (choice == 1){
			eraseDatabase();
		}

		else if (choice == 2) {
			loadAirlineInformation();
		}

		else if (choice == 3) {
			loadScheduleInformation();
		}

		else if (choice == 4) {
			loadPricingInformation();
		}

		else if (choice == 5) {
			loadPlaneInformation();
		}

		else if(choice == 6) {
			generatePassengerManifest();
		}

		else if(choice == 7){
			updateTimestamp();
		}

		return true;
	}

	//Admin TASK 1: erase the database
	private void eraseDatabase() throws IOException, SQLException {
		System.out.println("Type 'Y' if you are sure that you want to delete all of the data.\n"
				+ "Type any other key if you do not want to do that:\n");
		String verifyString = Menu.scan.nextLine();

		if (verifyString.equalsIgnoreCase("Y")) {
			try (Statement stmt = conn.createStatement()) {
				stmt.executeUpdate("TRUNCATE airline, plane, flight, price, customer, reservation, reservation_detail, ourtimestamp CASCADE;");
			}
		}
	}


	//Admin TASK 2: load airline information from text file
	private void loadAirlineInformation() throws IOException, SQLException {
		System.out.println("Please supply the filename where the airline information is stored:\n");
		String inputFile = Menu.scan.nextLine();

		try (PreparedStatement stmt = conn.prepareStatement("INSERT INTO airline(airline_id, airline_name, airline_abbreviation, year_founded) VALUES(?, ?, ?, ?);")) {
			int airID;
			String st;
			String[] splitTokens;
			String airline;
			String abbrev;
			int year;
			try (BufferedReader reader = new BufferedReader(new FileReader(inputFile))) {
				while((st = reader.readLine()) != null){
					splitTokens = st.split("\\t");
					airID = Integer.parseInt(splitTokens[0]);
					airline = splitTokens[1];
					abbrev = splitTokens[2];
					year = Integer.parseInt(splitTokens[3]);

					stmt.setInt(1, airID);
					stmt.setString(2, airline);
					stmt.setString(3,  abbrev);
					stmt.setInt(4, year);

					stmt.executeUpdate();
				}
			} catch (Exception e) {
				System.out.println("Error reading from the airline input file.");
			}
		} catch (Exception e) {
			System.out.println("Error loading the airline information.");
		}
	}

	//Admin TASK 3: load schedule information from text file
	private void loadScheduleInformation() throws SQLException, IOException {

		System.out.println("\nPlease type the file name for the airline Schedule");
		String path = Menu.scan.nextLine();

		try (PreparedStatement stmt = conn.prepareStatement("insert into flight values(?, ?, ?, ?, ?, ?, ?, ?);")) {
			int numb, airID;
			String line;
			String[] attributes;
			try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
				while((line = reader.readLine()) != null) {
					attributes = line.split("\\t");
					numb = Integer.parseInt(attributes[0]);
					airID = Integer.parseInt(attributes[1]);

					stmt.setInt(1, numb);
					stmt.setInt(2, airID);
					stmt.setString(3, attributes[2]);
					stmt.setString(4, attributes[3]);
					stmt.setString(5, attributes[4]);
					stmt.setString(6, attributes[5]);
					stmt.setString(7, attributes[6]);
					stmt.setString(8, attributes[7]);

					stmt.executeUpdate();
				}
			} catch (Exception e) {
				System.out.println("Error: the system could not read the schedule information file.");
			//	e.printStackTrace();
			}
		}
		catch (Exception e) {
			System.out.println("Error: the system could not read the schedule information properly.");
		}
	}

	//Admin TASK 4: load pricing information
	private void loadPricingInformation() throws SQLException, IOException {
		System.out.println("Type 'L' to load pricing information.\nType 'C' to change the price of an existing flight:\n");
		String input = Menu.scan.nextLine();

		// Change the price of an existing flight
		if (input.equalsIgnoreCase("C")) {
			try (PreparedStatement stmt = conn.prepareStatement("update price set high_price = ?, low_price = ? where departure_city = ? and arrival_city = ?;")) {
				System.out.println("Please supply the departure city (e.g., PIT, JFK): ");
				stmt.setString(4, Menu.scan.nextLine());

				System.out.println("Please supply the arrival city (e.g., PIT, JFK): ");
				stmt.setString(3, Menu.scan.nextLine());

				System.out.println("Please supply the high price of the route:\n");
				stmt.setInt(1, Integer.parseInt(Menu.scan.nextLine()));

				System.out.println("Please supply the low price of the route:\n");
				stmt.setInt(2, Integer.parseInt(Menu.scan.nextLine()));

				if (stmt.executeUpdate() > 0) {
					System.out.println("Pricing information changed!");
				} else {
					System.out.println("No route matching this departure city and arrival city found:\n");
				}
			}
			catch (Exception e) {
				System.out.println("Error: the system could not read the pricing information properly.");
			}
		}

		// Load pricing information
		else if (input.equalsIgnoreCase("L")) {
			try (PreparedStatement stmt = conn.prepareStatement("insert into price values (?, ?, ?, ?, ?);")) {
				System.out.println("\nPlease type the file name for the pricing information:\n");
				input = Menu.scan.nextLine();
				String[] attributes;

				try (BufferedReader reader = new BufferedReader(new FileReader(input))) {
					String line;
					while ((line = reader.readLine()) != null) {
						attributes = line.split("\\t");

						stmt.setString(1, attributes[0]);
						stmt.setString(2, attributes[1]);
						stmt.setInt(3, Integer.parseInt(attributes[2]));
						stmt.setInt(4, Integer.parseInt(attributes[3]));
						stmt.setInt(5, Integer.parseInt(attributes[4]));

						stmt.executeUpdate();
					}
				}
			}
			catch (Exception e) {
				System.out.println("Error: the system could not insert the pricing information properly.");
			}
		}
	}

	//Admin TASK 5: load plane information from text file
	private void loadPlaneInformation() throws SQLException, IOException {

		System.out.println("\nPlease type the file name for the Plane Information:\n");
		String path = Menu.scan.nextLine();

		try (PreparedStatement stmt = conn.prepareStatement("insert into plane values (?, ?, ?, TO_DATE(?, 'MM-DD-YYYY'), ?, ?);")) {
			String line;
			String[] attributes;

			try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
				while((line = reader.readLine()) != null){
					attributes = line.split("\\t");

					stmt.setString(1, attributes[0]);	//plane_type
					stmt.setString(2, attributes[1]);	//manufacturer
					stmt.setInt(3, Integer.parseInt(attributes[2]));	//plane_capacity
					stmt.setString(4, attributes[3]);	//last_service
					stmt.setInt(5, Integer.parseInt(attributes[4]));	//year
					stmt.setInt(6, Integer.parseInt(attributes[5]));	//owner_id

					stmt.executeUpdate();
				}
			}
		}
		catch (Exception e) {
			System.out.println("Error: the system could not read the plane information properly. Check input format");
		//	e.printStackTrace();
		}
	}


	//Admin TASK 6: Print Passenger Manifest for specified flight and date
	private void generatePassengerManifest() throws SQLException, IOException {
		System.out.println("Please supply flight number:\n");
		int flightNum = Integer.parseInt(Menu.scan.nextLine());
		System.out.println("Please supply date (ie MM-DD-YYYY) of flight:\n");
		String date = Menu.scan.nextLine();


		//Search reservation details & customer to find names of passengers on specified flight
		PreparedStatement stmt = conn.prepareStatement("select salutation, first_name, last_name, flight_date From customer natural join reservation natural join "
				+ "reservation_detail WHERE flight_date::DATE = ?::DATE  AND TICKETED = TRUE AND flight_number = ?;");
		stmt.setString(1, date);
		stmt.setInt(2, flightNum);

		try (ResultSet rs = stmt.executeQuery()) {
			stmt.close();
			System.out.println("Passenger manifest for flight " + flightNum + " on " + date + ":");

			while(rs.next()){
				String sal = rs.getString("salutation");
				String fname = rs.getString("first_name");
				String lname = rs.getString("last_name");
				System.out.println(sal + " " + fname + " " + lname);
			}
		}
		catch (Exception e) {
			System.out.println("Error: the system could not generate manifest for given flight and date.");
		}
	}

	//Admin TASK 7: Update the current timestamp
	// Ask the user to supply a date and time to be set as the current timestamp (c_timestamp) Menu.scan OurTimeStamp table
	private void updateTimestamp() throws SQLException, IOException {
		System.out.println("Please supply a date to set as the current system time.\nFormat: 'YYYY-MM-DD'. For example: '2020-11-05':\n");
		String dateString = Menu.scan.nextLine();

		System.out.println("Please supply a time to set as the current system time.\nFor example: '14:17:02.0");
		String timeString = Menu.scan.nextLine();

		try (PreparedStatement stmt = conn.prepareStatement("update ourtimestamp set c_timestamp = TO_TIMESTAMP(?, 'MM-DD-YYYY HH24:MI');")) {
			stmt.setString(1, dateString + " " + timeString);
			stmt.executeUpdate();
		}
		catch (Exception e) {
			System.out.println("Error: the system could not update the timestamp properly.");
		}
	}

}
