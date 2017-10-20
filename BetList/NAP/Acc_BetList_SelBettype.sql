ALTER PROCEDURE [dbo].[Acc_BetList_SelBettype]
	@CustId			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MoveBetsDay	DATETIME,
	@BalanceUpDay	DATETIME
AS

/*
	Created: Henry@20091228
	DB: DBAGE.bodb02

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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BettypeTable TABLE (BetType INT)

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @BettypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND custid = @CustId
			AND winlostdate BETWEEN @TempFromDate AND @todate
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

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		INSERT INTO @BettypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND custid = @CustId
			AND winlostdate BETWEEN @BalanceUpDay AND @TempToDate
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO @BettypeTable
		SELECT DISTINCT bettype
		FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND custid = @CustId
			AND winlostdate BETWEEN @FromDate AND @TempToDate
	END

	SELECT
		typeid,
		typenamee
	FROM dbo.bettype AS bt WITH (NOLOCK)
		INNER JOIN (SELECT DISTINCT BetType FROM @BettypeTable) btt ON bt.typeid = btt.BetType
END


GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelBettype] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_SelBettype] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_SelBettype] TO [vnteam]
GO
