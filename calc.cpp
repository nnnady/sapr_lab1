#include <iostream>
#include <stdexcept>
#include <string>
#include <cmath>

double add(double a, double b) { return a + b; }
double sub(double a, double b) { return a - b; }
double mul(double a, double b) { return a * b; }

double divide(double a, double b)
{
    if (b == 0)
        throw std::runtime_error("division by zero");
    return a / b;
}

// Возведение в степень (добавлено в ветке feature-power)
double power(double a, double b) { return std::pow(a, b); }

// Выбор операции по символу
double calculate(double a, char op, double b)
{
    switch (op)
    {
        case '+': return add(a, b);
        case '-': return sub(a, b);
        case '*': return mul(a, b);
        case '/': return divide(a, b);
        case '^': return power(a, b);
        default:  throw std::runtime_error(std::string("unknown operation: ") + op);
    }
}

int main()
{
    double a, b;
    char op;

    std::cout << "Enter expression (e.g. 2 + 3): ";
    if (!(std::cin >> a >> op >> b))
    {
        std::cerr << "Input error" << std::endl;
        return 1;
    }

    try
    {
        double result = calculate(a, op, b);
        std::cout << a << " " << op << " " << b << " = " << result << std::endl;
    }
    catch (const std::exception &e)
    {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
