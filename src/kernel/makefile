head.o: head.S
		gcc -E head.S > head.s
		as --64 -o head.o head.s
		rm head.s
