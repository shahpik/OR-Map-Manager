class TestClassSum:
    """
    You may want to group several tests into a test class
    In this case the class should have the naming convention: TestClass<name_of_test_group
    """
    def test_sum(self):
        # Test a true result
        assert sum([1, 2, 3]) == 6
        
    def test_sum_tuple(self):
        # Test a false result
        assert sum((1, 2, 2)) != 6