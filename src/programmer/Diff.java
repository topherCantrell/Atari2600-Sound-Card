package programmer;

import java.nio.file.Files;
import java.nio.file.Paths;

public class Diff {
	
	public static void main(String [] args) throws Exception {
		
		String [] programArgs = {"pacman.bin","from.bin"};args=programArgs;
		
		byte [] f1 = Files.readAllBytes(Paths.get(args[0]));
		byte [] f2 = Files.readAllBytes(Paths.get(args[1]));
		
		if(f1.length != f2.length) {
			System.out.println("Files are different lengths");
			return;
		}
		
		for(int x=0;x<f1.length;++x) {
			if(f1[x]!=f2[x]) {
				System.out.println("Files are different at "+x);
			}
		}
		
	}

}
