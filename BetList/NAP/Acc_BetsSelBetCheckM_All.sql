ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckM_All]
	@refno		BIGINT,
	@Language	NVARCHAR(2) = 'E'
AS

/*
	Created by: Henry
	Date: 2009-12-05
	Task: Get info of Mix Parlay Bets 
	DB: DBAGE.BODB02
	Original: Acc_BetsSelBetCheckM
	
	Revisions: 
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110513@Lukas: re-arrange bettype
		- 20110928@Johnson: get column statusid to mark void sub-ticket
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20130121@Dan: change linked server DB06 to DBARC		
		- 20141006@Sophia: get Betcheck
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Return transdesc to support PH All In One 1.2 [#Redmine: 50897]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetListMP TABLE (
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
		BetCheck		NVARCHAR(50),
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
			match.isNeutral,
			match.matchid,
			match.matchcode,
			bettrans.BetCheck,
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
				BetCheck,
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
			match.isNeutral,
			match.matchid,
			match.matchcode ,
			bettrans.BetCheck,
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
				BetCheck,
				transdesc
			FROM dbo.BettransM14 WITH (NOLOCK)
			WHERE refno = @refno) AS bettrans
		INNER JOIN dbo.match14 AS match WITH (NOLOCK) ON bettrans.matchid = match.matchid
	END

	IF EXISTS(SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM WITH (NOLOCK) WHERE refno = @refno)
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
			match.isNeutral,
			match.matchid,
			match.matchcode,
			bettrans.BetCheck,
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
				BetCheck,
				transdesc
			FROM DBARC.bodb_archive.dbo.BettransM WITH (NOLOCK)
			WHERE refno = @refno) AS bettrans
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS match WITH (NOLOCK) ON bettrans.matchid = match.matchid
	END

	SELECT * FROM @BetListMP
	ORDER BY TransID DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM_All] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckM_All] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetCheckM_All] TO [vnteam]
