/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelBettype]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20220729@Kos
	Task: NAP Left Panel => Member Bet List - Bettype dropdown
	DB: DBSIG.bodb02

	Revisions:
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetTypeTable TABLE (BetType INT)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	-- bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND custid = @CustId
			AND winlostdate BETWEEN @TempFromDate AND @ToDate
			--exclude metric gaming running ticket
			AND (bettype NOT BETWEEN 801 AND 806
				OR (bettype BETWEEN 801 AND 806 AND statusID NOT IN (0, 1)))
		UNION ALL
		SELECT DISTINCT gameID AS BetType
		FROM dbo.translog WITH (NOLOCK)
		WHERE winlostdate BETWEEN @TempFromDate AND @ToDate
			AND custid = @CustId
			AND statusID IN (0, 1)
	END

	-- Replace multiple bettypes which have the same name by group bet type ID
	INSERT INTO @BetTypeTable
	SELECT f.GroupTypeId
	FROM (SELECT * FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId) AS f
	WHERE f.BetType IN (SELECT DISTINCT BetType FROM @BetTypeTable)
		AND f.GroupTypeId NOT IN (SELECT DISTINCT BetType FROM @BetTypeTable)

	DELETE @BetTypeTable
	WHERE BetType IN ( SELECT BetType FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId)

	-- Don't support inactive products anymore
	DELETE b
	FROM @BetTypeTable AS b
	WHERE EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix WITH (NOLOCK)
				WHERE BetType = b.BetType
					AND ProductID IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33))

	SELECT
		typeid,
		typenamee
	FROM dbo.bettype AS bt WITH (NOLOCK)
		INNER JOIN (SELECT DISTINCT BetType FROM @BetTypeTable) btt ON bt.typeid = btt.BetType
END
GO
