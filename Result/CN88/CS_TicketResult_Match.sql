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
		- 20190807@Kos: Support PH AIO phase 4b [Redmine: #116865]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #121610]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200108@Kos: Support PH AIO phase 5 [Redmine: #124455]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ResultDetail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusID		TINYINT,
		SettlementStatusID	TINYINT,
		OtherInfo			VARCHAR(50))

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

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (9, 43, 193)
		BEGIN
			INSERT INTO @ResultDetail
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
						AND d.ResourceID LIKE f.ResourceID
						AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
							OR d.ResourceId IN ('08', '09')
							OR d.ResourceId LIKE '%' + @ResourceId))
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceID LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType = 9		-- Badminton
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @ResultDetail
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
		END
		ELSE
		BEGIN
			INSERT INTO @ResultDetail
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

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (9, 43, 193)
		BEGIN
			INSERT INTO @ResultDetail
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
						AND d.ResourceId LIKE f.ResourceID
						AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
							OR d.ResourceId IN ('08', '09')
							OR d.ResourceId LIKE '%' + @ResourceId))
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceID LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceID LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType = 9		-- Badminton
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM dbo.ResultDetailOS14 AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @ResultDetail
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
		END
		ELSE
		BEGIN
			INSERT INTO @ResultDetail
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

		-- Get sport type
		SELECT @SportType = Sporttype
		FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @MatchId

		SELECT @ResourceId = CASE
								WHEN @SportType = 5 THEN LEFT(REPLACE(CONVERT(VARCHAR(20), @BetId), '8', ''), 2)
								WHEN @BetType = 395 THEN RIGHT(CONVERT(VARCHAR(20), @BetId), 2)
								ELSE RIGHT(CONVERT(VARCHAR(20), @BetId), LEN(CONVERT(VARCHAR(20), @BetId)) - 1)
							END

		-- Get result detail
		IF @SportType NOT IN (9, 43, 193)
		BEGIN
			INSERT INTO @ResultDetail
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
						AND d.ResourceId LIKE f.ResourceID
						AND (@BetType NOT IN (486, 487, 395, 385, 384, 383, 382, 381)
							OR d.ResourceId IN ('08', '09')
							OR d.ResourceId LIKE '%' + @ResourceId))
					OR (@SportType = 2		-- Basketball
						AND (LEN(d.ResourceId) = 2
							OR (d.SettlementStatusID > 0
								AND d.ResourceId LIKE f.ResourceID
								AND (@BetType NOT IN (606, 607, 613, 617)
									OR d.ResourceId LIKE '%' + @ResourceId)))))
		END
		ELSE IF @SportType = 9		-- Badminton
		BEGIN
			INSERT INTO @ResultDetail
			SELECT
				d.MatchId,
				d.ResourceId,
				d.HomeValue,
				d.AwayValue,
				d.ResultStatusID,
				d.SettlementStatusID,
				d.OtherInfo
			FROM DBARC.bodb_Archive.dbo.ResultDetailOS_bk AS d WITH (NOLOCK)
				LEFT JOIN (SELECT Bettype, ResourceId FROM dbo.f_ResourceBettype()) AS f
					ON f.Bettype = @BetType AND d.ResourceId LIKE f.ResourceID
			WHERE d.MatchId = @MatchId
				AND (LEN(d.ResourceId) IN (2, 4)
					OR (d.SettlementStatusID > 0
						AND d.ResourceId LIKE f.ResourceID
						AND d.ResourceId LIKE '%' + @ResourceId))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @ResultDetail
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
		END
		ELSE
		BEGIN
			INSERT INTO @ResultDetail
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
		END
	END

	-- Don't show ResourceID '4860X', '488', '490' if ResourceID '08' exists
	IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '08')
	BEGIN
		DELETE FROM @ResultDetail
		WHERE ResourceId IN ('488', '490') OR ResourceId LIKE '486%'
	END

	-- Don't show ResourceID '4870X', '489' if ResourceID '09' exists
	IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '09')
	BEGIN
		DELETE FROM @ResultDetail
		WHERE ResourceId = '489' OR ResourceId LIKE '487%'
	END

	-- Don't show ResourceID '09' if ResourceID '490' exists
	IF EXISTS (SELECT 1 FROM @ResultDetail WHERE ResourceId = '490')
	BEGIN
		DELETE FROM @ResultDetail
		WHERE ResourceId = '09'
	END

	-- Return '08' FT Sequence, '09' 1H Sequence only if at least a goal/corner scored
	DELETE FROM @ResultDetail
	WHERE ResourceId IN ('08', '09')
		AND HomeValue NOT LIKE '%a%'
		AND HomeValue NOT LIKE '%h%'

	SELECT * FROM @ResultDetail
	ORDER BY ResourceId ASC
END
GO



GRANT EXECUTE ON [dbo].[CS_TicketResult_Match] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_TicketResult_Match] TO [bodbDownlineNetView]
GO
