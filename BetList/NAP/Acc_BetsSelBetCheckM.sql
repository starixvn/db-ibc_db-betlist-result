ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckM]
	@refno		BIGINT, -- transid
	@Language	NVARCHAR(2) = 'E'
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Get info of Mix Parlay Bets 
	DB: DBAGE.BODB02
	Original: Original: SP mteamlist
	
	Revisions: 
		- 20060222@[]: remove refno
		- 20060310@[]: remove odds depend
		- 20090408@PhuongDao: Get checktime as SettleTime 
		- 20090514@Simon: Remove RefNo
		- 20091003@Jamie: Remove comstatus out 
		- 20091125@Henry: Select appropriate info to avoid redundant data
		- 20091128@Daniel: Fix the issue Mix Parlay Tennis - Cross Day - Move Bet problems: get more data in bettransm14 for Refno in Bettrans 
		- 20091204@Henry: Change logic to get data for future Mix Parlay (combine Acc_BetsSelBetCheckM & Acc_BetsSelBetCheckM_History)
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110513@Lukas: re-arrange bettype
		- 20110928@Johnson: get column statusid to mark void sub-tickets
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20150415@Sophia: Get Betcheck for BEtRadar
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Return transdesc to support PH All In One 1.2 [#Redmine: 50897]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetListMP TABLE(
		TransID			BIGINT,
		Bettype			INT,
		HomeID			INT,
		AwayID			INT, 
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY,
		Odds			MONEY, 
		Betteam			NVARCHAR(20),
		statusid		INT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		Liveindicator	BIT,
		LeagueID		INT,
		Sporttype		SMALLINT,
		isNeutral		BIT,
		matchid			INT,
		matchcode		NVARCHAR(50),
		Betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(200)
	)

	IF EXISTS(SELECT 1 FROM bettransm WITH (NOLOCK) WHERE refno = @refno)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			bettrans.transid, 
			bettrans.bettype,
			match.homeid,
			match.awayid,
			bettrans.hdp1, 
			bettrans.hdp2, 
			bettrans.odds,
			bettrans.betteam,
			bettrans.statusid,
			bettrans.livehomescore, 
			bettrans.liveawayscore, 
			bettrans.liveindicator, 
			match.leagueid,
			match.sporttype,
			match.isNeutral AS IsNeutral,
			match.matchid,
			match.matchcode,
			bettrans.Betcheck,
			bettrans.transdesc
		FROM 
			(SELECT 
				matchid,
				Bettype,
				transid,
				hdp1,
				hdp2,
				odds,
				betteam,
				statusid,
				livehomescore,
				liveawayscore,
				liveindicator,
				Betcheck,
				transdesc
			FROM dbo.BettransM WITH (NOLOCK)
			WHERE refno = @refno ) AS bettrans
		INNER JOIN dbo.match WITH (NOLOCK) ON bettrans.matchid = match.matchid
	END

	IF EXISTS(SELECT 1 FROM bettransm14 WITH (NOLOCK) WHERE refno = @refno)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			bettrans.transid, 
			bettrans.bettype,
			match.homeid,
			match.awayid,
			bettrans.hdp1, 
			bettrans.hdp2, 
			bettrans.odds, 
			bettrans.betteam,
			bettrans.statusid,
			bettrans.livehomescore, 
			bettrans.liveawayscore, 
			bettrans.liveindicator, 
			match.leagueid,
			match.sporttype,
			match.isNeutral AS IsNeutral,
			match.matchid,
			match.matchcode,
			bettrans.Betcheck,
			bettrans.transdesc
		FROM 
			(SELECT
				matchid,
				Bettype,
				transid,
				hdp1,
				hdp2,
				odds,
				betteam,
				statusid,
				livehomescore,
				liveawayscore,
				liveindicator,
				Betcheck,
				transdesc
			FROM dbo.BettransM14 WITH (NOLOCK)
			WHERE refno = @refno) AS bettrans
		INNER JOIN dbo.match14 AS match WITH (NOLOCK) ON bettrans.matchid = match.matchid
	END

	SELECT * FROM @BetListMP
	ORDER BY TransID DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetCheckM] TO [vnteam]
