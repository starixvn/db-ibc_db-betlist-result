USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_BetList_SelParlayDetail]    Script Date: 10/17/2014 12:51:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelParlayByTransID]
	@TransId	BIGINT,
	@Language	VARCHAR(2) = 'E'
 AS
/*
Created:20141017@Bobby.Nguyen
Task: Get Betlist Parlay by TransID
DB: DBEXT/bodb02
Orgiginal: DBEXT/bodb02.dbo.Age_BetList_SelParlayDetail

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP
	- 20160425@Bobby.Nguyen: #56136 - Support Combo Parlay
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@tmpParlay	TABLE(
		transid		BIGINT,
		sporttype	INT,
		leagueid	INT,
		bettype		INT,
		MatchId		INT,
		homeid		INT,
		awayid		INT,
		Stake		MONEY,
		Currency	VARCHAR(10),
		hdp1		FLOAT,
		hdp2		FLOAT,
		odds		SMALLMONEY,
		betteam		NVARCHAR(50),
		statusid	INT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		liveindicator	BIT,
		betstatus	NVARCHAR(50),
		isNeutral	BIT,
		BetCheck	NVARCHAR(50),
		TransDesc	NVARCHAR(200)
	)	

	Declare @refno 		bigint
		, @custID 		int
		, @CurrencyCode	VARCHAR(3)

	SELECT @refno 		= refno
		, @custID 		= custid 
		, @CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
	from bettrans b with (NOLOCK) 
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	where TransID = @TransID
	IF @refno IS NULL 	
	BEGIN
		SELECT @refno = refno, @custID = custid 
			, @CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
		from bettrans14 b with (NOLOCK) 
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		where TransID = @TransID
		IF @refno IS NULL 
		BEGIN
			SELECT @refno = refno, @custID = custid 
				, @CurrencyCode = CASE WHEN ex.Code <> '' THEN ex.Code ELSE ex.currency END
			from DBARC.bodb_archive.dbo.bettrans_BK b with (NOLOCK) 
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			where TransID = @TransID
		END
	END
	IF EXISTS (SELECT 1 FROM bettransm WITH (NOLOCK) WHERE refno = @refno and custid = @custid)
	BEGIN
		INSERT INTO @tmpParlay (
			transid,
			sporttype,
			leagueid,
			bettype,
			MatchId,
			homeid,
			awayid,
			Stake,
			Currency,
			hdp1,
			hdp2,
			odds,
			betteam,
			statusid,
			livehomescore,
			liveawayscore,
			liveindicator,
			betstatus,
			isNeutral,
			BetCheck,
			transdesc
		)
		SELECT
			b.transid,
			m.Sporttype,
			m.LeagueID,		
			b.Bettype ,
			m.MatchId,
			m.homeID,
			m.awayID,
			b.Stake,
			@CurrencyCode AS Currency,
			convert(float, b.hdp1) as Hdp1, 
			convert(float, b.hdp2) as Hdp2, 
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.BetCheck,
			b.transdesc
		FROM(	SELECT 
						transid,
						matchid,  
						Bettype, 
						stake,
						hdp1, 
						hdp2, 
						odds, 
						betteam, 
						statusid,
						livehomescore,
						liveawayscore,
						liveindicator,
						BetCheck,
						ISNULL(transdesc, '') AS transdesc
				FROM	BettransM with (nolock)
						WHERE refno=@refno and custID = @custID              
			) AS b		
				inner join match as m with (nolock) on b.matchid=m.matchid
	END
	IF EXISTS (SELECT 1 FROM bettransm14 WITH (NOLOCK) WHERE refno = @refno and custid = @custid)
	BEGIN
		INSERT INTO @tmpParlay (
			transid,
			sporttype,
			leagueid,
			bettype,
			MatchId,
			homeid,
			awayid,
			Stake,
			Currency,
			hdp1,
			hdp2,
			odds,
			betteam,
			statusid,
			livehomescore,
			liveawayscore,
			liveindicator,
			betstatus,
			isNeutral,
			BetCheck,
			transdesc
		)
		SELECT
			b.transid,
			m.Sporttype,
			m.LeagueID,		
			b.Bettype ,
			m.MatchId,
			m.homeID,
			m.awayID,
			b.Stake,
			@CurrencyCode AS Currency,
			convert(float, b.hdp1) as Hdp1, 
			convert(float, b.hdp2) as Hdp2, 
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.BetCheck,
			b.transdesc
		FROM(	SELECT 
						transid,
						matchid,  
						Bettype, 
						stake,
						hdp1, 
						hdp2, 
						odds, 
						betteam, 
						statusid,
						livehomescore,
						liveawayscore,
						liveindicator,
						BetCheck,
						ISNULL(transdesc, '') AS transdesc
				FROM	BettransM14 with (nolock)
						WHERE refno=@refno and custID = @custID              
			) AS b		
				inner join match14 as m with (nolock) on b.matchid=m.matchid
	END
	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM WITH (NOLOCK) WHERE refno = @refno)
	BEGIN
		INSERT INTO @tmpParlay (
			transid,
			sporttype,
			leagueid,
			bettype,
			MatchId,
			homeid,
			awayid,
			Stake,
			Currency,
			hdp1,
			hdp2,
			odds,
			betteam,
			statusid,
			livehomescore,
			liveawayscore,
			liveindicator,
			betstatus,
			isNeutral,
			BetCheck,
			transdesc
		)
		SELECT
			b.transid,
			m.Sporttype,
			m.LeagueID,		
			b.Bettype ,
			m.MatchId,
			m.homeID,
			m.awayID,
			b.Stake,
			@CurrencyCode AS Currency,
			convert(float, b.hdp1) as Hdp1, 
			convert(float, b.hdp2) as Hdp2, 
			b.odds,
			b.Betteam,
			b.statusid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.BetCheck,
			b.transdesc
		FROM(	SELECT 
						transid,
						matchid,  
						Bettype, 
						stake,
						hdp1, 
						hdp2, 
						odds, 
						betteam, 
						statusid,
						livehomescore,
						liveawayscore,
						liveindicator,
						BetCheck,
						ISNULL(transdesc, '') AS transdesc
				FROM	DBARC.bodb_archive.dbo.BettransM with (nolock)
						WHERE refno=@refno  and custID = @custID          
			) AS b		
				inner join DBARC.bodb_archive.dbo.match_bk as m with (nolock) on b.matchid=m.matchid	
	END
	SELECT * FROM @tmpParlay
	ORDER BY transID DESC 
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelParlayByTransID] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelParlayByTransID] TO [bodbDownlineNet] AS [dbo]
GO
