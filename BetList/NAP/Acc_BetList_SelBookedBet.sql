/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelBookedBet]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@StatusIdList	VARCHAR(50)		= '',
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Task:
	DB: DBACC.bodb02
	Parameter's Explanation:
		- @StatusIdList:
			- 0: Booking
			- 1: Successful
			- 2: Unsuccessful
			- 3: ProcressingBet
			- 4: Cancelled
	Revisions:
		- 20240319@Razor: Init [Redmine: #202426]
		- 20240425@Razor: HF for filter checking time of Create time [Redmine: #204345]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data (
		TransId			BIGINT,
		CustId			INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		Hdp				SMALLMONEY,
		OddsType		TINYINT,
		OddsLower		MONEY,
		OddsUpper		MONEY,
		Stake			MONEY,
		TransDate		DATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		TransDesc		VARCHAR(500),
		StatusId		TINYINT,
		Reason			SMALLINT
	);

	CREATE TABLE #PagingData (
		TransId			BIGINT,
		CustId			INT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(20),
		Hdp				SMALLMONEY,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		OddsLower		MONEY,
		OddsUpper		MONEY,
		Stake			MONEY,
		TransDate		DATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(45),
		LeagueId		INT,
		MatchId			INT,
		EventDate		DATETIME,
		HomeId			INT,
		AwayId			INT,
		IsNeutral		BIT,
		TransDesc		VARCHAR(500),
		StatusId		TINYINT,
		Reason			SMALLINT
	);

	DECLARE @TempToDate	SMALLDATETIME
	SET @TempToDate = DATEADD(DAY, 1, @ToDate)

	IF ',' + @StatusIdList + ',' LIKE '%,0,%'
	BEGIN
		SET @StatusIdList = @StatusIdList + ',3'
	END

	INSERT INTO #Data (
		TransId,
		CustId,
		SportType,
		BetType,
		BetTeam,
		Hdp,
		OddsType,
		OddsLower,
		OddsUpper,
		Stake,
		StatusId,
		TransDate,
		LiveIndicator,
		LiveHomeScore,
		LiveAwayScore,
		Ip,
		LeagueId,
		MatchId,
		Reason,
		TransDesc,
		HomeId,
		AwayId)
	SELECT
		b.ReservationTicketId,
		b.custid,
		b.sporttype,
		b.bettype,
		b.betteam,
		b.Hdp,
		b.oddstype,
		b.OddsLower,
		b.OddsUpper,
		b.stake,
		b.status,
		b.createtime,
		b.IsLive,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.ip,
		b.leagueid,
		b.matchid,
		b.MatchingFailureReason,
		b.OddsInfo,
		b.HomeTeamId,
		b.AwayTeamId
	FROM dbo.ReservationTickets AS b WITH (NOLOCK)
	WHERE b.custid = @CustId
		AND b.Createtime >= @FromDate AND b.Createtime < @TempToDate
		AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.status) + ',%'


	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		SELECT @TotalRows = COUNT(TransId)
		FROM #Data

		DECLARE @RowStart INT,
			@RowEnd INT

		SELECT @PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex,
			@RowEnd = @RowStart + @PageSize

		INSERT INTO #PagingData (
			TransId,
			CustId,
			SportType,
			BetType,
			BetTeam,
			Hdp,
			OddsType,
			OddsLower,
			OddsUpper,
			Stake,
			StatusId,
			TransDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			LeagueId,
			MatchId,
			Reason,
			TransDesc,
			HomeId,
			AwayId)
		SELECT
			TransId,
			CustId,
			SportType,
			BetType,
			BetTeam,
			Hdp,
			OddsType,
			OddsLower,
			OddsUpper,
			Stake,
			StatusId,
			TransDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			LeagueId,
			MatchId,
			Reason,
			TransDesc,
			HomeId,
			AwayId
		FROM #Data
		ORDER BY TransId DESC
		OFFSET @RowStart ROWS FETCH NEXT @RowEnd ROWS ONLY

		UPDATE b
		SET
			EventDate = m.GlobalShowTime,
			Hdp1 = CASE
							WHEN b.Hdp > 0 THEN b.Hdp
							ELSE 0
						END,
			Hdp2 = CASE
							WHEN b.Hdp < 0 THEN -b.Hdp
							ELSE 0
						END,
			IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT,0))
		FROM #PagingData AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid

		UPDATE b
		SET
			EventDate = m.GlobalShowTime,
			Hdp1 = CASE
							WHEN b.Hdp > 0 THEN b.Hdp
							ELSE 0
						END,
			Hdp2 = CASE
							WHEN b.Hdp < 0 THEN -b.Hdp
							ELSE 0
						END,
			IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT,0))
		FROM #PagingData AS b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE b.EventDate IS NOT NULL
	END

	SELECT
		b.TransId,
		b.CustId,
		b.SportType,
		b.BetType,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsType,
		b.OddsLower,
		b.OddsUpper,
		b.Stake,
		b.TransDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.LeagueId,
		b.MatchId,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.IsNeutral,
		b.TransDesc,
		c.username,
		b.StatusId,
		b.Reason
	FROM #PagingData AS b
		INNER JOIN dbo.custinfo AS c WITH (NOLOCK) ON b.CustId = c.custid
	ORDER BY TransId DESC

	DROP TABLE #Data
	DROP TABLE #PagingData
END

