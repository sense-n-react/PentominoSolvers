-- -*- coding:utf-8 -*-

--
-- Pentomino Puzzle Solver with Lua
--

PIECE_DEF_DOC=[[
+-------+-------+-------+-------+-------+-------+
|       |   I   |  L    |  N    |       |       |
|   F F |   I   |  L    |  N    |  P P  | T T T |
| F F   |   I   |  L    |  N N  |  P P  |   T   |
|   F   |   I   |  L L  |    N  |  P    |   T   |
|       |   I   |       |       |       |       |
+-------+-------+-------+-------+-------+-------+
|       | V     | W     |   X   |    Y  | Z Z   |
| U   U | V     | W W   | X X X |  Y Y  |   Z   |
| U U U | V V V |   W W |   X   |    Y  |   Z Z |
|       |       |       |       |    Y  |       |
+-------+-------+-------+-------+-------+-------+
]]

PIECE_DEF = {}
--{
--   'F' = { { 2, 3}, { 3, 3}, { 1, 4}, { 2, 4}, { 2, 5} },
--   'P' = { {17, 3}, {18, 3}, {17, 4}, {18, 4}, {17, 5} },
--

-------------------------------------------------------------

string.split = function( self, sep )
   local ary = {}
   for e,s in self:gmatch( sep == "" and "." or "([^"..sep.."]*)("..sep.."?)" ) do
       table.insert( ary, e )
       if sep ~= "" and s == "" then break end
   end
   return ary
end

function map( ary, fn )
   local a = {}
   for i,v in ipairs(ary) do  a[i] = fn(v)  end
   return a
end

function fig2str( fig )
   local a = map( fig, function(xy)
                     return "(" .. table.concat( xy, ", " ) .. ")"
   end)
   return "[" .. table.concat( a, ", " ) .. "]"
end

--------------------------------------------------------------

Piece = {
   id   = nil,
   figs = {},
   next = nil,
   
   new = function ( self, id, fig_def, next )
      local figs     = {}
      local figs_str = ""
      for r_f = 1, 8 do                                      -- rotate & flip
         local fig = map( fig_def, function( xy )
             local x, y = xy[1], xy[2]
             for n = 1, r_f % 4 do                                 -- rotate
                x, y = -y, x
             end
             return (r_f > 4) and { -x, y } or { x, y }            -- flip
         end )

         table.sort( fig, function (a,b)                           -- sort
             return (a[2] == b[2]) and (a[1] < b[1]) or (a[2] < b[2])
         end )

         fig = map( fig, function( pt )                            -- normalize
             return { pt[1] - fig[1][1], pt[2] - fig[1][2] }
         end )

         if figs_str:find( fig2str(fig), 1, true ) == nil then     -- uniq
            table.insert( figs, fig )
            figs_str = figs_str .. fig2str(fig)
         end
      end

      local o = {
         id   = id,
         figs = figs,
         next = next,
      }

      if debug_flg then
         print( ("%s: (%d)"):format( o.id, #o.figs  ) )
         for _,fig in ipairs(figs) do
            print( ("   %s"):format( fig2str( fig ) ) )
         end
      end
      setmetatable( o, { __index = self } )

      return o
   end
} -- Piece

--------------------------------------------------------------

Board = {
   SPACE = ' ',
   cells = nil,

   new = function( self, w, h )
      local o = {
         width  = w,
         height = h,
         cells  = {},
      }

      for y = 1, h do
         o.cells[ y ] = {}
         for x = 1, w do
            o.cells[ y ][ x ] = self.SPACE
         end
      end
      if  w * h == 64 then           -- 8x8 or 4x16
         local cx, cy = math.floor( w / 2 ), math.floor( h / 2 )
         Board.place( o, cx, cy, { {0,0}, {0,1}, {1,0}, {1,1} }, '@' )
      end
      setmetatable( o, { __index = self } )
      return o
   end,


   at = function( self, x, y )
      if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
         return self.cells[ y ][ x ]
      else
         return '?'
      end
   end,


   check = function( self, ox, oy, fig )
      for _, pt in ipairs( fig ) do
        if self:at( ox + pt[1], oy + pt[2] ) ~= self.SPACE then
           return false
        end
     end
     return true
  end,


  place = function( self, ox, oy, fig, pc_id )
     for _, pt in ipairs( fig ) do
        self.cells[ oy + pt[2] ][ ox + pt[1] ] = pc_id
     end
  end,


  find_space = function( self, x, y )
     while Board.SPACE ~= self.cells[ y ][ x ] do
        x = ( x % self.width ) + 1
        if x == 1  then y = y + 1 end
     end
     return x, y
  end,


  --         2
  -- (-1,-1) | (0,-1)
  --   ---4--+--1----
  -- (-1, 0) | (0, 0)
  --         8

  ELEMS = map(
     {--  0      3     5    6    7     9    10   11   12   13   14   15
        "    ,,,+---,,----,+   ,+---,,+---,|   ,+---,+   ,+---,+   ,+---",
        "    ,,,    ,,    ,    ,    ,,|   ,|   ,|   ,|   ,|   ,|   ,|   "
     },
     function ( s ) return s:split( "," ) end
  ),

  render = function( self )
     local lines = {}
     for y = 1, self.height + 1 do
        for d = 1, 2 do
           local line = {}
           for x = 1, self.width + 1 do
              code = ( self:at(x+0, y+0) ~= self:at(x+0, y-1) and 1 or 0 ) +
                     ( self:at(x+0, y-1) ~= self:at(x-1, y-1) and 2 or 0 ) +
                     ( self:at(x-1, y-1) ~= self:at(x-1, y+0) and 4 or 0 ) +
                     ( self:at(x-1, y+0) ~= self:at(x+0, y+0) and 8 or 0 )
              table.insert( line, self.ELEMS[ d ][ code + 1 ] )
           end
           table.insert( lines, table.concat( line, "" ) )
        end
     end
     return table.concat( lines, "\n" )
  end

} -- Board

--------------------------------------------------------------

Solver = {
   solutions = 0,
   board     = nil,
   Unused      = nil,

   new = function( self, width, height )
      local pc = nil
      for id in ("FILNPTUVWXYZ"):reverse():gmatch( "." ) do
         pc = Piece:new( id, PIECE_DEF[id], pc )
      end
      -- limit the symmetry of 'F'
      pc.figs = ( width == height ) and
         { pc.figs[1] } or { pc.figs[1], pc.figs[2] }
      local o = {
         board    = Board:new( width, height ),
         Unused   = Piece:new( '!', {}, pc ),
         solutions = 0,
      }
      setmetatable( o, { __index = self } )
      return o
   end,


   solve = function( self, x, y )
      if  self.Unused.next ~= nil then
         x, y = self.board:find_space( x, y )
         local prev = self.Unused
         while true do
            local pc = prev.next
            if pc == nil then break end

            prev.next = pc.next
            for _, fig in ipairs(pc.figs) do
               if  self.board:check( x, y, fig ) == true then
                  self.board:place( x, y, fig, pc.id )
                  self:solve( x, y )
                  self.board:place( x, y, fig, self.board.SPACE )
               end
            end
            prev.next = pc
            prev      = pc
         end
      else
         self.solutions = self.solutions + 1
         curs_up = self.solutions > 1 and ("\27[%dA"):format( self.board.height * 2 + 2 ) or ""
         print( ("%s%s%d"):format( curs_up, self.board:render(), self.solutions ))
      end

   end,
} -- Solver

--------------------------------------------------------------

local width, height = 6, 10
local args = {...}
for _,av in ipairs(args)  do
   if av == "--debug"  then
      debug_flg = true
   end
   local sz = {}
   for n in av:gmatch( "%d+" ) do
      table.insert( sz, tonumber(n) )
   end
   if #sz == 2 and ( sz[1] * sz[2] == 60 or sz[1] * sz[2] == 64 ) then
      width, height = sz[1], sz[2]
   end
end

for y, line in ipairs( PIECE_DEF_DOC:split( "\n" ) ) do
   for x, c in ipairs( line:split( "" ) ) do
      if PIECE_DEF[ c ] == nil then  PIECE_DEF[ c ] = {}  end
      table.insert( PIECE_DEF[ c ], { math.floor( x/2 ), y } )
   end
end

solver = Solver:new( width, height )
solver:solve( 1, 1 )
