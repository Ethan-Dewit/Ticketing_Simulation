/*
 Team 8: Dāda Bäce
 Adam Nash awn10@pitt.edu
 Jason Henriquez jth79@pitt.edu
 Ethan Dewit erd56@pitt.edu
 */

import java.io.IOException;
import java.sql.*;
public interface User{
	public void showMenu();
	public boolean selectOption(int choice) throws IOException, SQLException;
	public void init(Connection conn);
}
