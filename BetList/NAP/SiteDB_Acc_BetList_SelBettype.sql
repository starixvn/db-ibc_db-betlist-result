/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelBettype]
	@CustId			INT,
	@ShadowIds		NVARCHAR(MAX) = NULL,
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
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20250207@Razor: Support SabaCoins multiple wallets [Redmine: 215807]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetTypeTable TABLE (BetType INT)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	DECLARE @TmpShadow TABLE (CustId INT)	
	INSERT INTO @TmpShadow (CustId)
	SELECT value
	FROM STRING_SPLIT(@ShadowIds, ',')
	WHERE value IS NOT NULL AND value != ''
	
	INSERT INTO @TmpShadow (CustId)
	SELECT @CustId
	-- bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
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
	FROM (SELECT GroupTypeId FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId) AS f
	WHERE f.BetType IN (SELECT DISTINCT BetType FROM @BetTypeTable)
		AND f.GroupTypeId NOT IN (SELECT DISTINCT BetType FROM @BetTypeTable)

	DELETE @BetTypeTable
	WHERE BetType IN ( SELECT BetType FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId)

	-- Don't support inactive products anymore
	DELETE b
	FROM @BetTypeTable AS b
	WHERE EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix WITH (NOLOCK)
				WHERE BetType = b.BetType
					AND ProductID IN (2, 4, 7, 9, 12, 13, 15, 17, 19, 24, 26, 30, 31, 33, 59))

	SELECT
		typeid,
		typenamee
	FROM dbo.bettype AS bt WITH (NOLOCK)
		INNER JOIN (SELECT DISTINCT BetType FROM @BetTypeTable) btt ON bt.typeid = btt.BetType
END
GO