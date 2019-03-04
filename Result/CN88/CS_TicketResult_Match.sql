/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_TicketResult_Match]
	@MatchId	INT,
	@BetType	SMALLINT	= NULL,
	@BetId		BIGINT		= NULL
AS

/*
	Created: Kos@20190304
	Task: Get ticket result of a match
	DB: DBAGE.bodb02
	Original: Age_BetList_SelMatchResult

	Revisions:
		- 20190304@Kos: Create new [Redmine: 109230]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ResourceId	VARCHAR(20),
		@SportType		SMALLINT

	-- Get result detail of bet type 221 in case of 225
	IF @BetType = 225
		SET @BetType = 221

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.GlobalShowTime AS kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			m.showtime
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)

		-- Get result detail
		IF @SportType NOT IN (43, 193)
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceID LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType <> 1324 THEN 2 ELSE
								CASE WHEN @BetType = 1324 AND LEFT(d.ResourceID, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceID))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%'
							OR d.ResourceID LIKE '226%'
							OR d.ResourceID LIKE '227%')
						AND (d.ResourceID <> '08'
							OR d.HomeValue LIKE '%a%'	-- Return '08' - Goal Sequence only if at least a goal scored
							OR d.HomeValue LIKE '%h%')
						AND d.ResourceID LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceID LIKE '%' + @ResourceId)))))
			ORDER BY d.ResourceID
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailES AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
			ORDER BY d.ResourceID
		END
		ELSE
		BEGIN
			SELECT
				d.MatchID,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail3rd AS d WITH (NOLOCK)
				LEFT JOIN (SELECT BetType, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.BetType = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchID = @MatchId
				AND (@SportType = 193
					AND d.SettlementStatusID > 0
					AND (d.ResourceId IN ('00', '01')
						OR (d.ResourceId LIKE f.ResourceID
							AND (@BetType <> 2809
								OR d.ResourceID LIKE '%' + @ResourceId))))
			ORDER BY d.ResourceId
		END
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			m.leagueid,
			m.matchid,
			m.homeid,
			m.awayid,
			m.matchcode,
			m.GlobalShowTime AS kickofftime,
			m.eventdate,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund,0) AS IsRefund,
			ISNULL(mr.calrefund,0) AS IsCalRefund,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			m.showtime
		FROM dbo.match14 AS m WITH(NOLOCK)
			LEFT OUTER JOIN dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.MatchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)

		-- Get result detail
		IF @SportType NOT IN (43, 193)
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT BetType, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.BetType = @BetType AND d.ResourceID LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType <> 1324 THEN 2 ELSE
								CASE WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceId))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%'
							OR d.ResourceID LIKE '226%'
							OR d.ResourceID LIKE '227%')
						AND (d.ResourceID <> '08'
							OR d.HomeValue LIKE '%a%'	-- Return '08' - Goal Sequence only if at least a goal scored
							OR d.HomeValue LIKE '%h%')
						AND d.ResourceId LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceID LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceID LIKE '%' + @ResourceId)))))
			ORDER BY d.ResourceID
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailES14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
			ORDER BY d.ResourceID
		END
		ELSE
		BEGIN
			SELECT
				d.MatchID,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetail3rd14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT BetType, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.BetType = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchID = @MatchId
				AND (@SportType = 193
					AND d.SettlementStatusID > 0
					AND (d.ResourceID IN ('00', '01')
						OR (d.ResourceID LIKE f.ResourceID
							AND (@BetType <> 2809
								OR d.ResourceID LIKE '%' + @ResourceId))))
			ORDER BY d.ResourceId
		END
	END
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.hthomescore,
			m.htawayscore,
			m.LeagueID,
			m.matchid,
			m.homeID,
			m.awayID,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype = 162 THEN m.kickofftime
				ELSE m.GlobalShowTime
			END kickofftime,
			m.finalhomescore,
			m.finalawayscore,
			m.livehomescore,
			m.liveawayscore,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(d.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund' 
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS eventstatus,
			ISNULL(mr.refund, 0) AS IsRefund,
			ISNULL(mr.calrefund, 0) AS IsCalRefund,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.goalrecord,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			m.showtime
		FROM DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
			LEFT OUTER JOIN DBARC.bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK) ON d.matchID = m.MatchID AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId
		ORDER BY m.eventdate,
			m.matchcode

		-- Get sport type
		SELECT @SportType = Sporttype
		FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @MatchId

		IF @SportType = 5
			SELECT @ResourceId = LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
		ELSE
			SELECT @ResourceId = RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)

		-- Get result detail
		IF @SportType NOT IN (43, 193)
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_Archive.dbo.ResultDetail_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND ((@SportType = 5		-- Tennis
						AND d.SettlementStatusID > 0
						AND CASE WHEN @BetType <> 1324 THEN 2 ELSE
								CASE WHEN @BetType = 1324 AND LEFT(d.ResourceId, 2) = @ResourceId THEN 4
									ELSE 0 END END = LEN(d.ResourceId))
					OR (@SportType = 1		-- Soccer
						AND (d.SettlementStatusID > 0
							OR d.ResourceID LIKE '221%'
							OR d.ResourceID LIKE '222%'
							OR d.ResourceID LIKE '223%'
							OR d.ResourceID LIKE '224%'
							OR d.ResourceID LIKE '225%'
							OR d.ResourceID LIKE '226%'
							OR d.ResourceID LIKE '227%')
						AND (d.ResourceID <> '08'
							OR d.HomeValue LIKE '%a%'	-- Return '08' - Goal Sequence only if at least a goal scored
							OR d.HomeValue LIKE '%h%')
						AND d.ResourceId LIKE f.ResourceID)
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
			ORDER BY d.ResourceId
		END
		ELSE IF @SportType = 43
		BEGIN
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_Archive.dbo.ResultDetailES_bk AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) = 2
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
			ORDER BY d.ResourceID
		END
		ELSE
		BEGIN
			SELECT
				d.MatchID,
				d.ResourceId,
				d.Custom1 AS HomeValue,
				d.Custom2 AS AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_BK AS d WITH (NOLOCK)
				LEFT JOIN (SELECT BetType, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.BetType = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchID = @MatchId
				AND (@SportType = 193
					AND d.SettlementStatusID > 0
					AND (d.ResourceID IN ('00', '01')
						OR (d.ResourceID LIKE f.ResourceID
							AND (@BetType <> 2809
								OR d.ResourceID LIKE '%' + @ResourceId))))
			ORDER BY d.ResourceId
		END
	END
END
GO



GRANT EXECUTE ON [dbo].[CS_TicketResult_Match] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_TicketResult_Match] TO [bodbDownlineNetView]
GO
