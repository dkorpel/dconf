/*
Example of the same function implemented with array allocation, and as a range
*/

ulong[] factorsOfArray(ulong x)
{
	ulong[] result;
	ulong p = 2;
	SmallPrimes primes;
	while (!primes.empty)
	{
		const q = x / p;
		const r = x % p;
		if (r == 0)
		{
			result ~= p;
			x = q;
			continue;
		}
		if (p > x)
			break;

		p = primes.front();
		primes.popFront();
	}

	void impl(ulong num)
	{
		if (num <= 1)
			return;

		const factor = findFactor(x);
		if (factor == 0 || factor == num)
			result ~= num;
		else
		{
			impl(factor);
			result ~= (num / factor);
		}
	}
	impl(x);
	return result[];
}

// ///////////////////////////////////////////////////////////////////////////////////////////////

struct FactorsOf
{
	private enum maxFactors = 32;
	ulong[maxFactors] stack;
	private ubyte si = 0; // index of first empty element on stack
	private ulong number; /// what's left of the numer to factorize
	private SmallPrimes primes = void; /// which prime number we're currently trying for trial division
	private ulong currentPrimeTrial = 2;
	private int stage = 0;

	this(ulong number)
	{
		this.primes = SmallPrimes();
		this.number = number;
		if (number != 0)
		{
			stack[si++] = 1;
			popFront();
		}
	}

	ulong front() const scope => stack[si - 1];

	bool empty() const scope => this.si == 0;

	void pushFactorsOnStack(ulong num)
	{
		do
		{
			if (num <= 1)
				return;
			const factor = findFactor(num);
			if (factor == 0)
			{
				stack[si++] = num;
				break;
			}
			else
			{
				stack[si++] = (num / factor);
				num = factor;
			}
		}
		while (true);
	}

	void popFront() scope
	{
		si--; // pop stack
		while (currentPrimeTrial != 0)
		{
			const q = number / currentPrimeTrial;
			const r = number % currentPrimeTrial;
			if (r == 0)
			{
				number = q;
				stack[si++] = currentPrimeTrial;
				if (q == 1)
					currentPrimeTrial = 0;
				return;
			}

			if (primes.empty || currentPrimeTrial >= number)
			{
				currentPrimeTrial = 0;
				stack[si++] = this.number;
				break;
			}
			else
			{
				currentPrimeTrial = primes.front();
				primes.popFront();
			}
		}

		if (!this.empty)
			pushFactorsOnStack(stack[--si]);
	}
}
