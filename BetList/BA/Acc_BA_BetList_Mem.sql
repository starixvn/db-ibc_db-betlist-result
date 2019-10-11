/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BA_BetList_Mem]
	@CustID			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@TotalRows		INT=0 OUTPUT,
	@SumWinlost		MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerComm    MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@drawfilter SMALLINT = 1,
	@Language VARCHAR(10) = 'en-us'  
AS

/*
	Created: Henry 
	Date: 2011-11-07
	Task : Betlist for Licensee Winloss Report
	DB: DBACC.bodb02

	Revisions:
		- 20111118@Henry: change to use CustID index hint instead of transid
		- 20111208@Jim: change condition bettype<31 
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120801@Jim: change formula to calculate Agent Commission 
		- 20130123@Daniel: Change link server alias
		- 20191011@Kos: Support drop table LicenseeBATransaction [Redmine: #103656]

	Param's Explanation:
		+ @drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
*/

BEGIN
	SET NOCOUNT ON

	declare @fdate DATETIME, @tdate datetime
	select @fdate = @FromDate, @tdate = @ToDate

	DECLARE	@currency INT 
	SELECT	@currency = currency FROM custinfo WITH (NOLOCK) WHERE custid = @custid

	DECLARE @BetListByDateMem AS TABLE (
		Sporttype		INT,
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Modds			SMALLMONEY,
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,	
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		LeagueID		INT,
		MatchID			INT,
		MatchCode		NVARCHAR(50),
		HomeID			INT,
		AwayID			INT, 	
		Betstatus		NVARCHAR(50),
		isNeutral		BIT,
		currency INT
	)

	DECLARE @TempBetList AS TABLE(
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Modds			SMALLMONEY,
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		Stake MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,	
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		currency INT,
		MatchID INT
	)

	Declare @TempFromDate DATETIME
	Declare @TempToDate DATETIME

	IF @tdate > @MoveBetsDay
	BEGIN
		IF @fdate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @fdate

		--general
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			0,
			comm ,
			ISNULL(b.playercomm,0),
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.matchid
		FROM
			dbo.bettrans AS b WITH (NOLOCK,INDEX=IX_custid)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid=@custid AND
			b.ruben = 1 AND
			b.statusID NOT IN (101, 102, 103)
	
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake, 
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,	
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			--'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999))  AND
			b.bettype NOT IN (9,29,10)
		
		--	Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				b.modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				'' AS Betteam, --Betteam
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				--m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				--0,0,
				b.currency
			FROM
				@TempBetList b		
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.bettype = 10

			--Mix Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				b.TransID,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam, --Betteam
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				--'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				--0,0,
				b.currency
			FROM
				@TempBetList b
			WHERE
				b.bettype = 9 AND
				b.matchid = 9
		
			--Combination Mixed Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				b.betteam, --Betteam
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				--'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				--0,0,
				b.currency
			FROM
				@TempBetList b
			WHERE
				b.bettype = 29	
				AND b.matchid = 29
	END

	IF @fdate <= @MoveBetsDay
	BEGIN
		IF @tdate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @tdate
	
		IF @BalanceUpDay < @fdate 
			SELECT @BalanceUpDay=@fdate

		DELETE FROM @TempBetList
	
		--general
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			0,
			comm ,
			ISNULL(b.playercomm,0),
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.matchid
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK,INDEX=bettrans1423)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.custid=@custid AND
			b.ruben = 1 AND
			b.statusID NOT IN (101, 102, 103) 
	
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,	
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			--'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR ( b.bettype BETWEEN 121 AND 999)) AND
			b.bettype NOT IN (9,29,10)
		
		--	Outright
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			b.BetID,
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,   
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			--m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b		
			INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10

		--Mix Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			--'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 
			
		--Combination Mixed Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,   
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			--'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
		WHERE
			b.bettype = 29	
			AND b.matchid = 29
	END

	IF @fdate < @BalanceUpDay
	BEGIN
		IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @tdate

		DELETE FROM @TempBetList
	
		--general
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			0,
			comm ,
			ISNULL(b.playercomm,0),
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.matchid
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK,INDEX=IX_custid)		
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate AND
			b.custid=@custid AND
			b.ruben = 1 AND
			b.status NOT IN ('VOID','REJECT','REFUND')
	
		--sport book
		INSERT INTO @BetListByDateMem
		SELECT
			m.Sporttype, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.Winlost,
			b.LicenseeWL,
			b.comm,	
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			--'' AS Race,
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
			INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999 )) AND
			b.bettype NOT IN (9,29,10)
		
		--	Outright
		INSERT INTO @BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			b.TransID,
			b.BetID,
			b.Bettype,
			0 AS hdp1, 
			0 AS hdp2, 
			b.modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			--m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b		
			INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10
		
		--Mix Parlay
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,   
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			--'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9
	
		--Combination Mixed Parlay	
		INSERT INTO @BetListByDateMem
		SELECT
			0, --Sporttype
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			modds,
			0 AS OddsType, 
			b.Odds, 
			b.stake,
			b.actual_stake,  
			b.betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,
			b.Winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			--'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			--0,0,
			b.currency
		FROM
			@TempBetList b
		WHERE
			b.bettype = 29	
			AND b.matchid = 29
	END

	UPDATE @BetListByDateMem
	SET betteam = dbo.Lrf_f_GetChoice(betteam,bettype,@Language)
	WHERE bettype IN (14,16)

	UPDATE @BetListByDateMem
	SET odds = CASE WHEN OddsType = 1 THEN odds + 1
					WHEN OddsType = 5 THEN odds * 100
					ELSE odds END		
	WHERE bettype IN (1,2,3,7,12,8,20)	

	UPDATE @BetListByDateMem
	SET OddsType = 0 
	WHERE bettype NOT IN (1,2,3,7,12,8,20)

	--exclude draw for no draw option (2)
	DELETE FROM @BetListByDateMem
	WHERE @drawfilter = 2 AND status = 'DRAW' AND ABS(modds) <> 0.25

	SELECT 
		@TotalRows = count(transid),
		@SumWinlost=SUM(ISNULL(winlost,0)),
		@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
		@SumComm=SUM(ISNULL(comm,0)) ,
		@SumPlayerComm=SUM(PlayerComm),
		--USD
		@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
		@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
		@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
		@SumPlayerCommUSD=SUM(PlayerComm*e.USD),
		--EUR
		@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
		@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
		@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)), 
		@SumPlayerCommEUR=SUM(PlayerComm*e.EUR)
	FROM @BetListByDateMem b
		INNER JOIN 
			ExchangeDailyOanda e WITH (NOLOCK) 
			ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency
	
	SELECT
		d.* , 
		--BASE RM
		d.stake*e.MYR		AS	StakeMYR,
		d.actual_stake*e.MYR		AS	actual_stakeMYR,
		d.winlost*e.MYR		AS	WinlostMYR,
		d.LicenseeWL*e.MYR	AS	LicenseeWLMYR,
		d.comm*e.MYR		AS	commMYR,
		d.PlayerComm*e.MYR  AS PlayerCommMYR,
		--BASEUSD
		d.stake*e.USD			AS	StakeUSD,
		d.actual_stake*e.USD	AS	actual_stakeUSD,
		d.winlost*e.USD			AS	WinlostUSD,
		d.LicenseeWL*e.USD		AS	LicenseeWLUSD,
		d.comm*e.USD			AS	commUSD,
		d.PlayerComm*e.EUR		AS PlayerCommEUR,	
		--BASEEUR
		d.stake*e.EUR			AS	StakeEUR,
		d.actual_stake*e.EUR	AS	actual_stakeEUR,
		d.winlost*e.EUR			AS	WinlostEUR,
		d.LicenseeWL*e.EUR		AS	LicenseeWLEUR,
		d.comm*e.EUR			AS	commEUR,
		d.PlayerComm*e.EUR      AS PlayerCommEUR
	FROM	@BetListByDateMem d 
			INNER JOIN ExchangeDailyOanda e WITH (NOLOCK) ON e.ExchangeDate =  d.winlostdate AND e.exchangeid = d.currency
	ORDER BY TransID
END
GO


GRANT EXECUTE ON [dbo].[Acc_BA_BetList_Mem] TO bodbAdminNet
GO
