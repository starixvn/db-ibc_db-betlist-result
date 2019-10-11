/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROC [dbo].[Acc_BA_BetList_ByTransID]
	@TransID bigint
AS

/*
Created: Henry 
Date: 2011-07-19
Task : Betlist for BA by TransID
DB: DB052.bodb02

Revisions:
	- 20110914: Show virtual rate + virtual amt
	- 20110929: Show column actual rate
	- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
	- 20111208@Jim:Change condition @Bettype 
	- 20120319@Henry: show main transid for sub-ticket of system parlay
	- 20120803@Jim: add playercomm value (for give commision to member) 
	
Param's Explanation:

*/

SET NOCOUNT ON

DECLARE @BetListByDateMem AS TABLE(
	Sporttype		INT,
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
	AmtDueToBAReal	MONEY,
	comm			MONEY,
	playercomm		MONEY,
	discount		DECIMAL(9,8),
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	LeagueID		INT,
	MatchID			INT,
	MatchCode		NVARCHAR(50),
	HomeID			INT,
	AwayID			INT, 	
	isNeutral		BIT,
	currency INT,
	CustID INT,
	virtualrate		float,
	actualrate		float,
	AmtDueToBAVirtual			MONEY
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
	AmtDueToBAReal	MONEY,
	comm			MONEY,
	playercomm 		MONEY,
	discount		DECIMAL(9,8),
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	currency INT,
	CustID INT,
	MatchID INT,
	virtualrate		float,
	actualrate		float,
	AmtDueToBAVirtual			MONEY
)

DECLARE @Bettype INT

IF EXISTS (SELECT 1 FROM bodb_Licensee.dbo.LicenseeBATransaction WITH (NOLOCK) WHERE TransID = @TransID)
BEGIN
	--Bettrans
	SELECT @Bettype = Bettype FROM bettrans WITH (NOLOCK) WHERE transid = @TransID AND bettype <> 29
	
	IF ISNULL(@Bettype,0) <> 0
	BEGIN
		--general
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.modds,
			b.oddstype,
			b.odds,
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate, 
			b.betteam, --Betteam
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,			
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			b.comm* b.actualrate AS acomm,
			b.playercomm* b.actualrate AS PlayerComm,
			b.discount,		
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.custid,
			b.matchid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		FROM
			bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK)	ON b.transid = BA.transid			
		WHERE
			b.TransID = @TransID
			
		--sportbook
		IF (@Bettype < 31 OR (@Bettype BETWEEN 121 AND 999 )) AND @Bettype NOT IN (9,29,10)
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
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
				b.AmtDueToBAReal,
				b.comm,
				b.playercomm,
				b.discount,		
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				m.HomeID,
				m.AwayID, 		
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				b.custid,
				b.virtualrate,
				b.actualrate,
				b.AmtDueToBAVirtual
			FROM
				@TempBetList b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		END

				
		-- Outright
		IF @Bettype = 10
		BEGIN
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
				b.AmtDueToBAReal,
				b.comm,
				b.playercomm,
				b.discount,	
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.TeamID, --HomeID
				0, --AwayID		
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				b.custid,
				b.virtualrate,
				b.actualrate,
				b.AmtDueToBAVirtual
			FROM
				@TempBetList b
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		END
		
		-- Mix Parlay		
		IF @Bettype = 9
		BEGIN
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
				b.AmtDueToBAReal,
				b.comm,	
				b.playercomm,
				b.discount,			
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				0, --HomeID
				0, --AwayID		
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				b.custid,
				b.virtualrate,
				b.actualrate,
				b.AmtDueToBAVirtual
			FROM
				@TempBetList b
		END
	END
	ELSE
	BEGIN
		--Bettrans14
		SELECT @Bettype = Bettype FROM bettrans14 WITH (NOLOCK) WHERE transid = @TransID AND bettype <> 29
		IF ISNULL(@Bettype,0) <> 0
		BEGIN
			--General
			INSERT INTO @TempBetList
			SELECT
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake * b.actualrate,
				b.actual_stake * b.actualrate,  
				b.betteam, --Betteam
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,			
				(b.winlost-actual_stake) * b.actualrate,
				- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
				b.comm* b.actualrate AS acomm,
				b.playercomm*b.actualrate  AS PlayerComm, 
				b.discount,		
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				b.currency,
				b.custid,
				b.matchid,
				b.virtualrate,
				b.actualrate,
				- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
			FROM
				bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK)	ON b.transid = BA.transid			
			WHERE
				b.TransID = @TransID
				
			--sportbook
			IF (@Bettype < 31 OR (@Bettype BETWEEN 121 AND 999 )) AND @Bettype NOT IN (9,29, 10)
			BEGIN
				INSERT INTO @BetListByDateMem
				SELECT
					m.Sporttype, 
					b.TransID,
					b.BetID,
					b.Bettype,
					b.hdp1, 
					b.hdp2, 
					modds,
					b.Oddstype,
					b.Odds,
					b.stake,
					b.actual_stake,   
					b.betteam, --Betteam
					b.status AS Status,				
					b.refno,
					b.Transdate,	
					b.winlostdate,	
					b.Winlost,					
					b.AmtDueToBAReal,
					b.comm,	
					b.playercomm,
					b.discount,		
					b.Liveindicator,
					b.Livehomescore,
					b.Liveawayscore,
					b.IP AS IP,
					m.LeagueID,
					m.MatchID,	
					m.MatchCode,
					m.HomeID,
					m.AwayID, 		
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					b.currency,
					b.custid,
					b.virtualrate,
					b.actualrate,
					b.AmtDueToBAVirtual
				FROM
					@TempBetList b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 					
			END
				
				
					
			--mix parlay
			IF @Bettype = 9
			BEGIN
				INSERT INTO @BetListByDateMem
				SELECT
					0, --Sporttype
					b.TransID,
					b.BetID,
					b.bettype,
					b.hdp1, 
					b.hdp2, 
					b.modds,
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
					b.AmtDueToBAReal,
					b.comm,
					b.playercomm,
					b.discount,	
					b.Liveindicator,
					b.Livehomescore,
					b.Liveawayscore,
					b.IP AS IP,
					0, --LeagueID
					0, --MatchID
					'',--MatchCode
					0, --HomeID
					0, --AwayID		
					CONVERT(BIT,0) AS isNeutral,
					b.currency,
					b.custid,
					b.virtualrate,
					b.actualrate,
					b.AmtDueToBAVirtual
				FROM
					@TempBetList b
			END
			
			
				
			--Outright
			IF @Bettype = 10
			BEGIN
				INSERT INTO @BetListByDateMem
				SELECT
					l.sporttype, --Sporttype
					b.TransID,
					b.BetID,
					b.Bettype,
					0 AS hdp1, 
					0 AS hdp2, 
					modds,
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
					b.AmtDueToBAReal,
					b.comm,	
					b.playercomm,
					b.discount,	
					0 AS LiveIndicator, 
					b.LiveHomescore, 
					b.LiveAwayscore,
					b.IP AS IP,
					m.LeagueID,
					m.OrId,--0, --MatchID	
					m.MatchCode,
					m.TeamID, --HomeID
					0, --AwayID		
					CONVERT(BIT,0) AS isNeutral,
					b.currency,
					b.custid,
					b.virtualrate,
					b.actualrate,
					b.AmtDueToBAVirtual
				FROM
					@TempBetList b
					INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			END	
			
			
		END
		ELSE
		BEGIN
			--BettransBK
			SELECT @Bettype = Bettype FROM DB06.bodb_archive.dbo.bettrans_BK WITH (NOLOCK) WHERE transid = @TransID AND bettype <> 29 
			IF ISNULL(@Bettype,0) <> 0
			BEGIN
				--for general
				INSERT INTO @TempBetList	
				SELECT
					b.TransID,
					b.BetID,
					b.Bettype,
					b.hdp1, 
					b.hdp2,
					b.modds,
					b.Oddstype,
					b.Odds,
					b.stake * b.actualrate,
					b.actual_stake * b.actualrate,   
					b.betteam, --Betteam
					b.status AS Status,				
					b.refno,
					b.Transdate,	
					b.winlostdate,			
					(b.winlost-actual_stake) * b.actualrate,
					- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
					b.comm * b.actualrate AS comm ,
					b.playercomm*b.actualrate AS PlayerComm, 
					b.discount,		
					b.Liveindicator,
					b.Livehomescore,
					b.Liveawayscore,
					b.IP AS IP,
					b.currency,
					b.custid,
					b.matchid,
					b.virtualrate,
					b.actualrate,
					- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
				FROM
					db052.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK)
					INNER JOIN DB06.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK) ON b.transid = BA.transid		
				WHERE
					b.TransID = @TransID
					
				
				
				--soccer	
				IF (@bettype < 31 OR (@Bettype BETWEEN 121 AND 999 )) AND @bettype NOT IN(9,29, 10)
				BEGIN
					INSERT INTO @BetListByDateMem
					SELECT
						m.Sporttype, 
						b.TransID,
						b.BetID,
						b.Bettype,
						b.hdp1, 
						b.hdp2,
						modds,
						b.Oddstype,
						b.Odds,
						b.stake,
						b.actual_stake,   
						b.betteam, --Betteam
						b.status AS Status,				
						b.refno,
						b.Transdate,	
						b.winlostdate,			
						b.winlost,
						b.AmtDueToBAReal,
						b.comm,
						b.playercomm,
						b.discount,		
						b.Liveindicator,
						b.Livehomescore,
						b.Liveawayscore,
						b.IP AS IP,
						m.LeagueID,
						m.MatchID,	
						m.MatchCode,
						m.HomeID,
						m.AwayID, 		
						ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
						b.currency,
						b.custid,
						b.virtualrate,
						b.actualrate,
						b.AmtDueToBAVirtual
					FROM
						@TempBetList b	
						INNER JOIN DB06.bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
				END
				
				
				-- Outright
				IF @Bettype = 10
				BEGIN
					INSERT INTO @BetListByDateMem
					SELECT
						l.sporttype, --Sporttype
						b.TransID,
						ISNULL(b.BetID,0),
						b.Bettype,
						0 AS hdp1, 
						0 AS hdp2, 
						modds,
						0 AS OddsType, 
						b.Odds, 
						b.stake,
						b.actual_stake,   
						'' AS Betteam, --Betteam
						b.Status,				
						b.refno,
						b.Transdate,	
						b.winlostdate,						
						b.winlost,
						b.AmtDueToBAReal,
						b.comm,
						b.playercomm,
						b.discount,	
						0 AS LiveIndicator , 
						b.LiveHomescore, 
						b.LiveAwayscore,
						b.IP AS IP,
						m.LeagueID,
						m.OrId,--0, --MatchID	
						m.MatchCode,
						m.TeamID, --HomeID
						0, --AwayID		
						CONVERT(BIT,0) AS IsNeutral,
						b.currency,
						b.custid,
						b.virtualrate,
						b.actualrate,
						b.AmtDueToBAVirtual
					FROM
						@TempBetList b		
						INNER JOIN DB06.bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid=m.orid
						INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				END
				
				IF @Bettype = 9
				BEGIN
					-- Mix Parlay		
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
						b.winlost,
						b.AmtDueToBAReal,
						b.comm,
						b.playercomm,
						b.discount,			
						b.Liveindicator,
						b.Livehomescore,
						b.Liveawayscore,
						b.IP AS IP,
						0, --LeagueID
						0, --MatchID	
						'',--MatchCode
						0, --HomeID
						0, --AwayID		
						CONVERT(BIT,0) AS IsNeutral,
						b.currency,
						b.custid,
						b.virtualrate,
						b.actualrate,
						b.AmtDueToBAVirtual
					FROM
						@TempBetList b
				END	
				
			END
		END
	END
	 
		
END

IF NOT EXISTS (SELECT 1 FROM @BetListByDateMem)  --- system parlay
BEGIN
	DECLARE @refno BIGINT,@custid INT

	SELECT @refno = refno,@custid=custid FROM bettrans b WITH(NOLOCK) 
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE b.transid = @transid 
	
	

	IF @refno IS NULL	
	BEGIN
		SELECT @refno = refno,@custid=custid FROM bettrans14 b WITH(NOLOCK) 
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE b.transid = @transid 	
	END

	IF @refno IS NULL	
	BEGIN
		SELECT @refno = refno,@custid=custid FROM DB06.bodb_archive.dbo.bettrans_bk b WITH(NOLOCK) 
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE b.transid = @transid 	
		
	END
	
	IF @refno IS NOT NULL
	BEGIN
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
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate,   
			b.betteam, --Betteam
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			b.comm * b.actualrate AS acomm,
			b.playercomm*b.actualrate  AS PlayerComm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		from	bettrans as b with (nolock)   
		where	 
				b.custid = @Custid  
				--and matchid=0  
				and matchid = 29
				and bettype = 29  
				and b.refno = @refno
				
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
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate,   
			b.betteam, --Betteam
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			b.comm * b.actualrate AS acomm,
			b.playercomm*b.actualrate as PlayerComm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		from	bettrans14 as b with (nolock)   
		where	 
				b.custid = @Custid  
				and matchid = 29
				and bettype = 29  
				and b.refno = @refno
		
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
			b.stake * b.actualrate,
			b.actual_stake * b.actualrate,   
			b.betteam, --Betteam
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake) * b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.actualrate,
			b.comm * b.actualrate AS acomm,
			b.playercomm*b.actualrate AS PlayerComm,
			b.discount,			
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			0, --HomeID
			0, --AwayID		
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			b.custid,
			b.virtualrate,
			b.actualrate,
			- (b.winlost - b.actual_stake + b.comm) * b.virtualrate
		from	DB06.bodb_archive.dbo.bettrans_bk as b with (nolock)   
		where	 
				b.custid = @Custid  
				and matchid = 29
				and bettype = 29  
				and b.refno = @refno
				
	END
			
END




IF ISNULL(@Bettype,0) <> 0
BEGIN
	--Update Betteam, odds and oddstype	
	
	UPDATE @BetListByDateMem
	SET betteam = dbo.f_GetChoice(betteam,bettype,'E')
	WHERE bettype IN (14,16)
	
	UPDATE @BetListByDateMem
	SET odds = CASE WHEN OddsType = 1 THEN odds + 1
					WHEN OddsType = 5 THEN odds * 100
					ELSE odds END		
	WHERE bettype IN (1,2,3,7,12,8,20)


	UPDATE @BetListByDateMem
	SET OddsType = 0 
	WHERE bettype NOT IN (1,2,3,7,12,8,20)

	
END


SELECT
	b.*,
	c.UserName ,
    SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,
    e.currency AS CurrencyName
FROM @BetListByDateMem b
	INNER JOIN Customer c WITH (NOLOCK) ON b.CustID = c.CustID
	INNER JOIN Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid




GRANT EXECUTE ON [dbo].[Acc_BA_BetList_ByTransID] TO bodbAdminNet
GO
