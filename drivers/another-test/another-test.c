#include <kunit/test.h>

static void test1(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 1, 1);
}

static void test2(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 2, 2);
}

static void test3(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 3, 3);
}

static struct kunit_case case1[] = {
	KUNIT_CASE(test1),
	{}
};

static struct kunit_case case2[] = {
	KUNIT_CASE(test2),
	KUNIT_CASE(test3),
	{}
};

static struct kunit_suite suite1 = {
	.name = "suite1",
	.test_cases = case1,
};

static struct kunit_suite suite2 = {
	.name = "suite2",
	.test_cases = case2,
};

kunit_test_suites(&suite1, &suite2);

MODULE_LICENSE("GPL v2");
