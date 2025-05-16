/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelBettype]
	@CustId				INT,
	@ShadowIds			NVARCHAR(MAX) = NULL,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ExcludeBettrans	BIT			= 0
AS

/*
	Created: Henry@20091228
	DB: DBACC.bodb02

	Revisions:
		- 20100113@Henry: Newly created
		- 20110516@Lukas: Re-arrange bettype
		- 20110524@Henry: Change to use winlostdate instead of transdate
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20140311@Dom: Add Keno translog
		- 20150615@Edward: Remove bettype 903 of BetTrade
		- 20150529@Tom: Add filter by custid on translog
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170315@Kos: Exclude bet type 913, 914 [#Redmine: 71963]
		- 20171019@Kos: Include Waiting tickets in translog [#Redmine: 84961]
		- 20180308@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191007@Kos: Move to DBACC [Redmine: #120379]
		- 20220808@Kos: Scale out DBTRANS [Redmine: #175253]
					- Add new input param @ExcludeBettrans BIT
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
	IF @ToDate > @MoveBetsDay AND @ExcludeBettrans = 0
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

	-- bettrans14 range
	IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @FromDate < @BalanceUpDay
			SET @TempFromDate = @BalanceUpDay
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND winlostdate BETWEEN @TempFromDate AND @TempToDate
	END

	-- bettrans_bk range
	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND winlostdate BETWEEN @FromDate AND @TempToDate
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
					AND ProductID IN (2, 4, 7, 9, 12, 13, 15, 17, 19, 24, 26, 30, 31, 33, 59))

	SELECT
		typeid,
		typenamee
	FROM dbo.bettype AS bt WITH (NOLOCK)
		INNER JOIN (SELECT DISTINCT BetType FROM @BetTypeTable) btt ON bt.typeid = btt.BetType
END
GO
