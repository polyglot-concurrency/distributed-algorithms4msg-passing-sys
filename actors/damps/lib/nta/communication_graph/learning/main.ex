# Author José Albert Cruz Almaguer <jalbertcruz@gmail.com>
# Copyright 2016 by José Albert Cruz Almaguer.
#
# This program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http:www.gnu.org/licenses/agpl-3.0.txt) for more details.

defmodule NTA.CommunicationGraph.Learning.Main do
    alias NTA.CommunicationGraph.Learning.Process, as: MainProcess

    def run do

        p1 = MainProcess.new
        p2 = MainProcess.new
        p3 = MainProcess.new
        p4 = MainProcess.new

        MainProcess.set_neighbors(p1, [p2, p3])

        MainProcess.set_neighbors(p2, [p3, p4])

        MainProcess.start(p1)

    end

end
