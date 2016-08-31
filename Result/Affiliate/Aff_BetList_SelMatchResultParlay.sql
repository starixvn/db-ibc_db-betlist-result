USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_BetList_SelMatchResultParlay]    Script Date: 10/17/2014 8:36:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Aff_BetList_SelMatchResultParlay]
	@refno	BIGINT
AS
/*
Created:20141017@Bobby.Nguyen
Task: Get Result Page
DB: DBEXT/bodb02
Orgiginal: DBEXT/bodb02.dbo.Age_BetList_SelMatchResult

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP & Get the detail information of Tennis sport
	- 20150415@Bobby.Nguyen: Support for new 60 bettypes betradar
	- 20160425@Bobby.Nguyen: #56136 - Support Combo Parlay
*/
BEGIN

	SET NOCOUNT ON;
	
	DECLARE	@tmpParlay TABLE(
		sporttype	INT,
		leagueid	INT,
		matchid		INT,
		homeID		INT,
		awayID		INT,
		hthomescore	INT,
		htawayscore	INT,
		finalhomescore INT,
		finalawayscore INT,
		kickofftime DATETIME,
		eventdate	DATETIME,
		isNeutral	BIT,
		betstatus	VARCHAR(50),
		eventstatus	VARCHAR(15),
		IsRefund	BIT,
		IsCalRefund	BIT,
		goalrecord	VARCHAR(50),
		matchcode	VARCHAR(50),
		isHTCal		BIT,
		calculate	BIT,
		IsPending	BIT, 
		Bettype		SMALLINT,
		Betcheck	VARCHAR(50),
		TransDesc	NVARCHAR(200)
	)

	DECLARE @tmpResultDetail AS TABLE (
		MatchId INT ,
		ResourceId VARCHAR(20),
		HomeValue VARCHAR(20),
		AwayValue VARCHAR(20),
		ResultStatusID TINYINT,
		SettlementStatusID TINYINT,
		OtherInfo VARCHAR(50)
	)


	IF EXISTS (SELECT 1 FROM dbo.bettransm WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		;WITH BettransMix AS (
			SELECT b.matchId
				, b.Bettype, REPLACE (ISNULL(b.Betcheck,''),'8','') AS Betcheck
				, ISNULL(transdesc, '') AS transdesc
			FROM dbo.BettransM b WITH (NOLOCK) 
			WHERE b.refno = @refno 
		)
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending, 
			Bettype, 
			Betcheck,
			transdesc
		)
		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				CASE m.Sporttype WHEN 5 THEN CASE ISNULL(D.SettlementStatusID,0)	 
										WHEN 1 THEN 'Refund' 
										WHEN 2 THEN 'Refund HT'
										WHEN 3 THEN 'Refund FT'
									ELSE m.eventstatus END 
								ELSE 
									CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
											WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
											WHEN m.betstatus like 'Refund%' THEN 'Refund' 
									ELSE m.eventstatus END 
						END AS eventstatus, 
				ISNULL(mr.refund,0) IsRefund ,
				ISNULL(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) AS isHTCal,
				ISNULL(mr.calculate,0) AS calculate	,
				ISNULL(mr.IsPending,0) AS IsPending,
				bm.Bettype, 
				bm.Betcheck,
				bm.transdesc
		FROM BettransMix bm
			INNER JOIN dbo.match m WITH(NOLOCK) 
			ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) 
			ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail D WITH (NOLOCK) 
			ON D.matchID = M.MatchID 
				AND D.ResourceId = '00'
		
		-- select from result detail
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID,
					D.OtherInfo
			FROM	dbo.ResultDetail D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId	
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F 					
					ON	F.Bettype = P.Bettype					
						AND D.ResourceId LIKE F.ResourceID						
			WHERE	 D.SettlementStatusID > 0
					 AND (	(P.Sporttype = 5 AND CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
								 					 CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(REPLACE (ISNULL(P.Betcheck,''),'8','') ,2) THEN 4 
														ELSE 0 END END = LEN(D.ResourceId)
							 )
							OR 
							(P.Sporttype = 1 AND D.ResourceId NOT IN ( '00', '01', '08') 
							 AND D.ResourceId LIKE F.ResourceID		 	 
							 	
							)
						)

	END
	IF EXISTS (SELECT 1 FROM dbo.bettransm14 WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		WITH BettransMix AS (	
			SELECT b.matchId
				, b.Bettype, REPLACE (ISNULL(b.Betcheck,''),'8','') AS Betcheck
				, ISNULL(transdesc, '') AS transdesc
			FROM dbo.BettransM14 b WITH (NOLOCK) 
			WHERE b.refno = @refno 
		)
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending,
			Bettype, 
			Betcheck,
			transdesc
		)
		SELECT	m.sporttype, 	
				m.LeagueID,
				m.matchid, 	
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				CASE m.Sporttype WHEN 5 THEN CASE ISNULL(D.SettlementStatusID,0)	 
										WHEN 1 THEN 'Refund' 
										WHEN 2 THEN 'Refund HT'
										WHEN 3 THEN 'Refund FT'
									ELSE m.eventstatus END 
								ELSE 
									CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
											WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
											WHEN m.betstatus like 'Refund%' THEN 'Refund' 
									ELSE m.eventstatus END 
						END AS eventstatus, 
				ISNULL(mr.refund,0) IsRefund ,
				ISNULL(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode, 
				ISNULL(mr.isHTCal,0) AS isHTCal,
				ISNULL(mr.calculate,0) AS calculate,
				ISNULL(mr.IsPending,0) AS IsPending,
				bm.Bettype, 
				bm.Betcheck,
				bm.transdesc
		FROM BettransMix bm
			INNER JOIN dbo.match14 m WITH(NOLOCK) 
			ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) 
			ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 D WITH (NOLOCK) 
			ON D.matchID = M.MatchID 
				AND D.ResourceId = '00'
		
		-- select from result detail
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID,
					D.OtherInfo
			FROM	dbo.ResultDetail14 D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId	
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F 					
					ON	F.Bettype = P.Bettype					
						AND D.ResourceId LIKE F.ResourceID						
			WHERE	 D.SettlementStatusID > 0
					 AND (	(P.Sporttype = 5 AND CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
								 					 CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(REPLACE (ISNULL(P.Betcheck,''),'8','') ,2) THEN 4 
														ELSE 0 END END = LEN(D.ResourceId)
							 )
							OR 
							(P.Sporttype = 1 AND D.ResourceId NOT IN ( '00', '01', '08') 
							 AND D.ResourceId LIKE F.ResourceID		 	 
							 	
							)
						)
					 

	END
	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.BettransM  WITH (NOLOCK) WHERE  refno = @refno)
	BEGIN
		WITH BettransMix AS (	
			SELECT b.matchId
				, b.Bettype,REPLACE (ISNULL(b.Betcheck,''),'8','') AS Betcheck
				, ISNULL(transdesc, '') AS transdesc				
			FROM DBARC.bodb_archive.dbo.BettransM b (NOLOCK) 
			WHERE b.refno = @refno 
		)
		INSERT INTO @tmpParlay (
			sporttype, 	
			LeagueID,
			matchid, 	
			homeID,
			awayID,
			hthomescore,
			htawayscore,		
			finalhomescore,
			finalawayscore,
			kickofftime,
			eventdate,
			isNeutral,
			betstatus, 	
			eventstatus,
			IsRefund ,
			IsCalRefund,
			goalrecord,
			matchcode,
			isHTCal,
			calculate,
			IsPending,
			Bettype, 
			Betcheck,
			transdesc
		)
		SELECT	m.sporttype, 
				m.LeagueID,
				m.matchid, 			
				m.homeID,
				m.awayID,
				hthomescore,
				htawayscore,		
				m.finalhomescore,
				m.finalawayscore,
				ISNULL(m.globalshowtime, m.kickofftime), -- kickofftime
				m.eventdate,
				m.isNeutral,
				m.betstatus, 	
				CASE m.Sporttype WHEN 5 THEN CASE ISNULL(D.SettlementStatusID,0)	 
										WHEN 1 THEN 'Refund' 
										WHEN 2 THEN 'Refund HT'
										WHEN 3 THEN 'Refund FT'
									ELSE m.eventstatus END 
								ELSE 
									CASE  WHEN m.betstatus like 'Refund FT%' THEN 'Refund FT' 
											WHEN m.betstatus like 'Refund HT%' THEN 'Refund HT'
											WHEN m.betstatus like 'Refund%' THEN 'Refund' 
									ELSE m.eventstatus END 
						END AS eventstatus,
				ISNULL(mr.refund,0) IsRefund ,
				ISNULL(mr.calrefund,0) IsCalRefund,
				m.goalrecord,
				m.matchcode,
				ISNULL(mr.isHTCal,0) AS isHTCal,
				ISNULL(mr.calculate,0) AS calculate,
				ISNULL(mr.IsPending,0) AS IsPending,
				bm.Bettype, 
				bm.Betcheck,
				bm.transdesc
		FROM BettransMix bm
			INNER JOIN DBARC.bodb_archive.dbo.match_BK m WITH(NOLOCK) 
			ON bm.matchid = m.matchid
			LEFT OUTER JOIN dbo.match_remark mr WITH(NOLOCK) 
			ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK) 
			ON D.matchID = M.MatchID 
				AND D.ResourceId = '00'
		
		-- select from result detail
		INSERT INTO @tmpResultDetail
		SELECT		D.MatchId,
					D.ResourceId,
					D.HomeValue,
					D.AwayValue,
					D.ResultStatusID,
					D.SettlementStatusID,
					D.OtherInfo
			FROM	DBARC.bodb_archive.dbo.ResultDetail_BK D WITH (NOLOCK)
				INNER JOIN @tmpParlay P 
					ON D.MatchId = P.MatchId	
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) F 					
					ON	F.Bettype = P.Bettype					
						AND D.ResourceId LIKE F.ResourceID						
			WHERE	 D.SettlementStatusID > 0
					 AND (	(P.Sporttype = 5 AND CASE WHEN P.Bettype NOT IN (1324) THEN 2 ELSE 
								 					 CASE WHEN P.Bettype IN (1324) AND LEFT(D.ResourceId,2) = LEFT(REPLACE (ISNULL(P.Betcheck,''),'8','') ,2) THEN 4 
														ELSE 0 END END = LEN(D.ResourceId)
							 )
							OR 
							(P.Sporttype = 1 AND D.ResourceId NOT IN ( '00', '01', '08') 
							 AND D.ResourceId LIKE F.ResourceID		 	 
							 	
							)
						)
	END
	
	SELECT * FROM @tmpParlay
	ORDER BY LeagueID, eventdate, matchcode	

	SELECT DISTINCT * FROM @tmpResultDetail
	ORDER BY MatchID, ResourceId
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultParlay] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelMatchResultParlay] TO [bodbDownlineNet] AS [dbo]
GO
