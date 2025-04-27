--1 List student who major_id is 1
Select Student_ID , FirstName , MidName,LastName  , Major_ID  from Student where Major_ID =1; 

--2 List student is Male and Birthday is after 2000 
select Student_ID, MidName, FirstName, LastName, Sex, Birthday from Student Where( Sex ='m' or Sex ='M') and Birthday >'2000-12-31' ;

--3 Count the number of students in each province
Select p.ProvinceName , count(s.Student_ID) total_student 
from Student s left join Province p on s.Province_ID = p.Province_ID
group by p.ProvinceName

--4. List the name of students who have no training point
Select s.Student_ID  , s.FirstName  ,s.MidName ,s.LastName,  sum(st.Point) as Total_TPoint  
from Student s  inner join Student_Trainingpoint st  on s.Student_ID = st .Student_ID  
group by s.Student_ID  , s.FirstName ,s.MidName ,s.LastName
having sum(st.Point) is null ; 

--5. List the student total classes and calculate the total class credit hour, order by total credit hour decrease
SELECT s.Student_ID, s.FirstName, s.LastName, g.Semester ,COUNT(DISTINCT c.Class_ID) TotalClasses, SUM(c.CreditHour) TotalCreditHours
FROM Student s LEFT JOIN Grade g ON s.Student_ID = g.Student_ID
LEFT JOIN Class c ON g.Class_ID = c.Class_ID
GROUP BY s.Student_ID, s.FirstName, s.LastName, g.Semester
order by TotalCreditHours desc

/*6. Create a Totalfee column in the SchoolFee table, calculate the total fee for each students and add the data in the column.
List both the totalfee and the students who have paid the fee */
Alter table Schoolfee 
add Totalfee  int;

update Schoolfee  
set Totalfee = Classfee + OtherFee ; 
select s.Student_ID, S.FirstName,s.MidName, s.LastName, sf.Totalfee ,sf.Have_Paid from Student s
inner join Schoolfee sf on sf.Student_ID = s.Student_ID where Have_Paid ='Y' or Have_Paid ='y';

--7 . List all teachers who are teaching at least two different majors and sort them by last name.
select t.Teacher_ID , t.Teacher_LastName ,t.Teacher_MidName ,t.Teacher_FirstName ,count(tm.Teacher_ID) numberofmajor 
From  Teacher t join Teacher_Major tm  on t.Teacher_ID =tm.Teacher_ID 
Group By t.Teacher_ID , t.Teacher_LastName ,t.Teacher_MidName ,t.Teacher_FirstName 
Having count(tm.Teacher_ID) > 2 
Order By t.Teacher_LastName ;

--8 Calculate the GPA of each student and from that adding the GPA and Letter grade column in the Grade table 
--8.1 Create function to calculate GPA
Create function dbo.total_grade (@DailyScore int, @MidtermEScore int, @FinalEScore int) returns float
as
begin
    RETURN ((@DailyScore * 0.1) + (@MidtermEScore * 0.3) + (@FinalEScore * 0.6))
END ;
--8.2 Adding atribute
Alter table Grade 
add GPA float, Letter_grade char(2);
--8.3 Adding data
Update Grade
SET GPA = dbo.total_grade(DailyScore , MidtermEScore ,  FinalEScore) / 2.5,
Letter_grade = case
	When dbo.total_grade(DailyScore ,  MidtermEScore,  FinalEScore) between 8.95 and 10 Then 'A+'
	When dbo.total_grade(DailyScore, MidtermEScore ,  FinalEScore) between 8.45 And 8.94 Then 'A'
	When dbo.total_grade(DailyScore , MidtermEScore, FinalEScore) between 7.95 and 8.44 Then 'B+'
	When dbo.total_grade(DailyScore,  MidtermEScore,  FinalEScore) between 6.95 and 7.94 Then 'B'
	When dbo.total_grade(DailyScore , MidtermEScore, FinalEScore) between 6.45 and 6.94 Then 'C+'
	When dbo.total_grade(DailyScore, MidtermEScore  , FinalEScore) between 5.45 and 6.44 Then 'C'
	When dbo.total_grade(DailyScore, MidtermEScore , FinalEScore) between 4.95 and 5.44 Then 'D+'
	When dbo.total_grade(DailyScore  , MidtermEScore  , FinalEScore) between 3.95 and 4.94 Then 'D'
	When dbo.total_grade(DailyScore  , MidtermEScore  , FinalEScore) < 3.95 Then 'F'
	else null
end;
Select * from Grade order by GPA desc

/*9. Using the GPA from the Grade table and training points from the Student_Trainingpoint,
select 10 students that have the highest total GPA and training points in a semester qualified for a scholarship, 
each student will randomly be assigned to a scholarship and add it to the student_scholaship table */
--Function to get the top 10 ranked students
CREATE FUNCTION dbo.GetRankedTopStudents()
RETURNS @TopStudents TABLE (
    Student_ID INT,
    FirstName VARCHAR(15),
    LastName VARCHAR(15),
    TotalGPA FLOAT,
    TotalTrainingPoints INT,
    Rank INT
)
AS
BEGIN
    WITH 
	--Ranking the student by GPA and training point
	RankingStudents AS (
        SELECT s.Student_ID, s.FirstName, s.LastName, 
               SUM(g.GPA) AS TotalGPA, 
               SUM(st.Point) AS TotalTrainingPoints,
               ROW_NUMBER() OVER (ORDER BY SUM(g.GPA) DESC, SUM(st.Point) DESC) AS Rank
        FROM Student s JOIN Grade g ON s.Student_ID = g.Student_ID 
			JOIN Student_Trainingpoint st ON s.Student_ID = st.Student_ID
        GROUP BY s.Student_ID, s.FirstName, s.LastName
    )
	--Return the data of the top 10 student
    INSERT INTO @TopStudents (Student_ID, FirstName, LastName, TotalGPA, TotalTrainingPoints, Rank)
    SELECT Student_ID, FirstName, LastName, TotalGPA, TotalTrainingPoints, Rank
    FROM RankingStudents
    WHERE Rank <= 10;
    RETURN;
END;
--Create procedure for random assignment and data insertion

CREATE OR ALTER PROCEDURE AssignScholarshipsToTopStudents
AS
BEGIN
    -- Temporary table to hold top students with their assigned scholarships
    DECLARE @TopStudents TABLE (Student_ID INT, Scholarship_ID INT, Semester VARCHAR(50));
    -- Insert data from the function into the temporary table, excluding students who already have a scholarship
    INSERT INTO @TopStudents (Student_ID, Scholarship_ID, Semester)
    SELECT ts.Student_ID, s.Scholarship_ID, 'Spring 2024'
    FROM dbo.GetRankedTopStudents() ts CROSS JOIN Scholarship s
    WHERE ts.Student_ID NOT IN (SELECT DISTINCT Student_ID FROM Student_Scholar);
    -- Insert the randomly assigned scholarships into the Student_Scholar table
    INSERT INTO Student_Scholar (Student_ID, Scholarship_ID, Semester)
    SELECT Student_ID, Scholarship_ID, Semester
    FROM (SELECT Student_ID, Scholarship_ID, Semester,ROW_NUMBER() OVER (PARTITION BY Student_ID ORDER BY NEWID()) AS RowNum
		FROM @TopStudents) ts
    WHERE ts.RowNum = 1;
    -- Select the inserted rows to verify
    SELECT * FROM Student_Scholar;
END;

-- Execute the stored procedure to assign scholarships and display the results
EXEC AssignScholarshipsToTopStudents;

--10. For the students who have scholarships, the total school fee will deducted by the scholarship prize for the students who haven't paid the fee yet
--10.1 Create new atribute for the SchoolFee table
ALTER TABLE Schoolfee 
ADD AfterScholarshipDeduction int;
--10.2 Adding data to the new atribute
UPDATE Schoolfee
SET AfterScholarshipDeduction = Totalfee - s.Scholarship_prize
FROM Schoolfee sf
INNER JOIN Student_Scholar ss ON sf.Student_ID = ss.Student_ID
INNER JOIN Scholarship s ON ss.Scholarship_ID = s.Scholarship_ID
WHERE sf.Have_Paid = 'N';
SELECT Student_ID, Have_Paid, Totalfee, AfterScholarshipDeduction
FROM Schoolfee
where AfterScholarshipDeduction is not null