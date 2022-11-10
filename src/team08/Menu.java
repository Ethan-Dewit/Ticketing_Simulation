/*
 Team 8: Dāda Bäce
 Adam Nash awn10@pitt.edu
 Jason Henriquez jth79@pitt.edu
 Ethan Dewit erd56@pitt.edu
 */

import java.util.Scanner;
import java.sql.*;

public class Menu {

	public static Scanner scan = new Scanner(System.in);


	public static void main(String[] args) {
		Connection conn = null;
		try{
			System.out.println("Connecting to " + Info.URL);
			conn = DriverManager.getConnection(Info.URL, Info.USERNAME, Info.PASSWORD);
			System.out.println("Connected Successfully\n");
		}

		catch (SQLException e) {
			System.out.println("Error: could not connect to our system. Please contact the Pitt Tours hotline.");
		}

		User user;
		int choice = -1;

		// Layer that determines whether user is customer or administrator
		while (true) {
			System.out.println("Welcome to Pitt Tours.\n" +
					"Type the corresponding number for your given choice.\n" +
					"1. I am a customer.\n" +
					"2. I am an administrator.\n");

			try {
				choice = Integer.parseInt(scan.nextLine());
			} catch (Exception e) {
				System.out.println("That's not a valid selection. Try again.");
			}

			if ((user = getUser(choice)) != null) {
				break;
			}
		}

		user.init(conn);

		// User layer that shows the menu of options and prompts the user to make a choice
		while(true) {
			user.showMenu();

			try{
				choice = Integer.parseInt(scan.nextLine());
				boolean hasNotQuit = user.selectOption(choice);

				if (!hasNotQuit) {
					break;
				}
			}

			catch(NumberFormatException e) {
				System.out.println("Error: expected numerical input, but received non-numerical input.");
			}

			catch(Exception e) {
				//e.print Trace();
				//System.exit(1);
				System.out.println("That's not a valid selection. Try again.");
			}
		}

		try {
			if(conn != null) {
				conn.close();
				scan.close();
			}
		}

		catch(SQLException t){
			System.out.println("Error: could not connect to the system. Please contact the Pitt Tours hotline.");
		}

		finally {
			System.out.println("Goodbye! Thanks for using Pitt Tours!");
		}
	}

	// Factory which establishes whether the user is a customer or administrator
	private static User getUser(int choice) {
		if (choice == 1) {
			return new Customer();
		}
		else if (choice == 2) {
			return new Administrator();
		}

		return null;
	}
}